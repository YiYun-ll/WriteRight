import { handleGradingWorker } from "../_shared/jobs/http.ts";

Deno.serve(handleGradingWorker);
