locals {
  container_name = "${var.name_prefix}-web"
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_ecs_task_definition" "this" {
  family                   = local.container_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name                   = local.container_name
      image                  = "${var.repository_url}:${var.image_tag}"
      essential              = true
      user                   = "1000:1000"
      privileged             = false
      readonlyRootFilesystem = true
      versionConsistency     = "enabled"
      stopTimeout            = 30

      portMappings = [{
        name          = "http"
        containerPort = 8080
        hostPort      = 8080
        protocol      = "tcp"
        appProtocol   = "http"
      }]

      environment = [
        for name in sort(keys(var.environment_variables)) : {
          name  = name
          value = var.environment_variables[name]
        }
      ]

      healthCheck = {
        command = [
          "CMD-SHELL",
          "node -e \"fetch('http://127.0.0.1:8080/api/health').then(r=>{if(!r.ok)process.exit(1)}).catch(()=>process.exit(1))\"",
        ]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }

      linuxParameters = {
        initProcessEnabled = true
        capabilities = {
          add  = []
          drop = ["ALL"]
        }
      }

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = var.log_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "web"
          mode                  = "blocking"
        }
      }
    },
  ])

  tags = var.tags
}

resource "aws_ecs_service" "this" {
  name                               = "${var.name_prefix}-service"
  cluster                            = aws_ecs_cluster.this.id
  task_definition                    = aws_ecs_task_definition.this.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  platform_version                   = "LATEST"
  scheduling_strategy                = "REPLICA"
  health_check_grace_period_seconds  = 60
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200
  enable_execute_command             = false
  wait_for_steady_state              = true
  propagate_tags                     = "SERVICE"

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  dynamic "alarms" {
    for_each = length(var.rollback_alarm_names) > 0 ? [1] : []
    content {
      alarm_names = var.rollback_alarm_names
      enable      = true
      rollback    = true
    }
  }

  deployment_controller {
    type = "ECS"
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.task_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = local.container_name
    container_port   = 8080
  }

  tags = var.tags
}
