import { CronExpressionParser } from 'cron-parser';
import { getPool, sql } from '../db/sql';
import { runScript } from './scriptRunner';

let schedulerStarted = false;
let schedulerRunning = false;

function getNextRunAt(cronExpression: string): Date {
  const interval = CronExpressionParser.parse(cronExpression, {
    currentDate: new Date()
  });

  const next = interval.next().toDate();

  return new Date(next.getTime() - 6 * 60 * 60 * 1000);
}

export function startScheduler() {
  if (schedulerStarted) return;

  schedulerStarted = true;

  console.log('[SCHEDULER] Scheduler iniciado.');

  setInterval(async () => {
    if (schedulerRunning) return;

    schedulerRunning = true;

    try {
      const pool = await getPool();

      const result = await pool.request().query(`
        SELECT
          id,
          script_id,
          cron_expression,
          next_run_at
        FROM dbo.Schedules
        WHERE is_active = 1
          AND next_run_at <= GETDATE()
      `);

      for (const schedule of result.recordset) {
        try {
          console.log(`[SCHEDULER] Ejecutando schedule ${schedule.id}, script ${schedule.script_id}`);

          const paramsResult = await pool.request()
            .input('schedule_id', sql.Int, schedule.id)
            .query(`
              SELECT
                param_key,
                param_value
              FROM dbo.ScheduleParameters
              WHERE schedule_id = @schedule_id
            `);

          const scheduleParameters: Record<string, string> = {};

          for (const p of paramsResult.recordset) {
            scheduleParameters[p.param_key] = String(p.param_value ?? '');
          }

          await runScript(
            schedule.script_id,
            undefined,
            scheduleParameters
          );

          const nextRunAt = getNextRunAt(schedule.cron_expression);

          await pool.request()
            .input('id', sql.Int, schedule.id)
            .input('next_run_at', sql.DateTime, nextRunAt)
            .query(`
              UPDATE dbo.Schedules
              SET
                last_run_at = GETDATE(),
                next_run_at = @next_run_at,
                updated_at = GETDATE()
              WHERE id = @id
            `);

          console.log(`[SCHEDULER] Próxima ejecución schedule ${schedule.id}: ${nextRunAt.toISOString()}`);
        } catch (err: any) {
          console.error(`[SCHEDULER] Error ejecutando schedule ${schedule.id}:`, err.message);

          await pool.request()
            .input('id', sql.Int, schedule.id)
            .input('error_message', sql.NVarChar(sql.MAX), err.message)
            .query(`
              UPDATE dbo.Schedules
              SET
                last_error = @error_message,
                updated_at = GETDATE()
              WHERE id = @id
            `);
        }
      }
    } catch (err: any) {
      console.error('[SCHEDULER] Error general:', err.message);
    } finally {
      schedulerRunning = false;
    }
  }, 60000);
}