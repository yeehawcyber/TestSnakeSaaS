import {
  LambdaClient,
  PutFunctionConcurrencyCommand,
} from "@aws-sdk/client-lambda";

const client = new LambdaClient({});

export async function handler(event) {
  const functionName = process.env.TARGET_FUNCTION;
  if (!functionName) {
    throw new Error("TARGET_FUNCTION is required.");
  }

  console.warn("AWS budget guard triggered; disabling web Lambda concurrency.", {
    functionName,
    records: Array.isArray(event?.Records) ? event.Records.length : 0,
  });

  await client.send(
    new PutFunctionConcurrencyCommand({
      FunctionName: functionName,
      ReservedConcurrentExecutions: 0,
    }),
  );

  return { disabled: true, functionName };
}
