import { Router } from 'express';
import { CronExpressionParser } from 'cron-parser';
import { getPool, sql } from '../db/sql';
import { env } from '../config/env';

const router = Router();

function calculateNextRunAt(cronExpression: string): Date {
  const interval = CronExpressionParser.parse(cronExpression, {
    currentDate: new Date()
  });

  const next = interval.next().toDate();
  return new Date(next.getTime() - 6 * 60 * 60 * 1000);
}

router.get('/', async (_req, res, next) => {
  try {
    const pool = await getPool();

    const result = await pool.request().query(`
      SELECT
        sch.id,
        sch.script_id,
        s.name AS script_name,
        sch.cron_expression,
        sch.frequency_label,
        sch.next_run_at,
        sch.last_run_at,
        sch.last_status,
        sch.is_active
      FROM dbo.Schedules sch
      JOIN dbo.Scripts s ON s.id = sch.script_id
      ORDER BY sch.next_run_at
    `);

    res.json(result.recordset);
  } catch (err) {
    next(err);
  }
});

router.post('/', async (req, res, next) => {
  try {
    const body = req.body || {};

    const scriptId = Number(body.scriptId || body.script_id);
    const cronExpression = String(body.cronExpression || body.cron_expression || '').trim();
    const parameters = body.parameters || {};

    if (!scriptId) {
      return res.status(400).json({
        error: true,
        message: 'Debe seleccionar un script.'
      });
    }

    if (!cronExpression) {
      return res.status(400).json({
        error: true,
        message: 'Debe ingresar una expresión CRON.'
      });
    }

    let nextRunAt: Date;

    try {
      nextRunAt = calculateNextRunAt(cronExpression);
    } catch {
      return res.status(400).json({
        error: true,
        message: 'La expresión CRON no es válida.'
      });
    }

    const pool = await getPool();

    const transaction = new sql.Transaction(pool);

    await transaction.begin();

    try {
      const request = new sql.Request(transaction);

      const result = await request
        .input('script_id', sql.Int, scriptId)
        .input('created_by_user_id', sql.Int, body.created_by_user_id || env.defaultUserId)
        .input('cron_expression', sql.NVarChar(100), cronExpression)
        .input('frequency_label', sql.NVarChar(150), body.frequency || body.frequency_label || null)
        .input('next_run_at', sql.DateTime2, nextRunAt)
        .query(`
          INSERT INTO dbo.Schedules (
            script_id,
            created_by_user_id,
            cron_expression,
            frequency_label,
            next_run_at
          )
          OUTPUT INSERTED.*
          VALUES (
            @script_id,
            @created_by_user_id,
            @cron_expression,
            @frequency_label,
            @next_run_at
          )
        `);

      const schedule = result.recordset[0];

      for (const [key, value] of Object.entries(parameters)) {
        const paramRequest = new sql.Request(transaction);

        await paramRequest
          .input('schedule_id', sql.Int, schedule.id)
          .input('param_key', sql.NVarChar(150), String(key))
          .input('param_value', sql.NVarChar(sql.MAX), value === null || value === undefined ? null : String(value))
          .query(`
            INSERT INTO dbo.ScheduleParameters (
              schedule_id,
              param_key,
              param_value
            )
            VALUES (
              @schedule_id,
              @param_key,
              @param_value
            )
          `);
      }

      await transaction.commit();

      res.status(201).json(schedule);
    } catch (err) {
      await transaction.rollback();
      throw err;
    }
  } catch (err) {
    next(err);
  }
});

router.delete('/:id', async (req, res, next) => {
  try {
    const pool = await getPool();

    await pool.request()
      .input('id', sql.Int, Number(req.params.id))
      .query(`
        UPDATE dbo.Schedules
        SET is_active = 0
        WHERE id = @id
      `);

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

router.patch('/:id/toggle', async (req, res, next) => {
  try {
    const pool = await getPool();

    await pool.request()
      .input('id', sql.Int, Number(req.params.id))
      .query(`
        UPDATE dbo.Schedules
        SET 
          is_active = CASE WHEN is_active = 1 THEN 0 ELSE 1 END,
          updated_at = GETDATE()
        WHERE id = @id
      `);

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

router.get('/:id', async (req, res, next) => {
  try {
    const pool = await getPool();

    const scheduleId = Number(req.params.id);

    const schedule = await pool.request()
      .input('id', sql.Int, scheduleId)
      .query(`
        SELECT *
        FROM dbo.Schedules
        WHERE id = @id
      `);

    const params = await pool.request()
      .input('id', sql.Int, scheduleId)
      .query(`
        SELECT
          param_key,
          param_value
        FROM dbo.ScheduleParameters
        WHERE schedule_id = @id
      `);

    res.json({
      schedule: schedule.recordset[0],
      parameters: params.recordset
    });

  } catch (err) {
    next(err);
  }
});

router.put('/:id', async (req, res, next) => {
  try {
    const pool = await getPool();

    const scheduleId = Number(req.params.id);
    const body = req.body || {};
    const parameters = body.parameters || {};

    const transaction = new sql.Transaction(pool);

    await transaction.begin();

    try {

      await new sql.Request(transaction)
        .input('id', sql.Int, scheduleId)
        .input('cron_expression', sql.NVarChar(100), body.cronExpression)
        .input('frequency_label', sql.NVarChar(150), body.frequency)
        .query(`
          UPDATE dbo.Schedules
          SET
            cron_expression = @cron_expression,
            frequency_label = @frequency_label,
            updated_at = GETDATE()
          WHERE id = @id
        `);

      await new sql.Request(transaction)
        .input('id', sql.Int, scheduleId)
        .query(`
          DELETE FROM dbo.ScheduleParameters
          WHERE schedule_id = @id
        `);

      for (const [key, value] of Object.entries(parameters)) {

        await new sql.Request(transaction)
          .input('schedule_id', sql.Int, scheduleId)
          .input('param_key', sql.NVarChar(150), String(key))
          .input('param_value', sql.NVarChar(sql.MAX), String(value ?? ''))
          .query(`
            INSERT INTO dbo.ScheduleParameters (
              schedule_id,
              param_key,
              param_value
            )
            VALUES (
              @schedule_id,
              @param_key,
              @param_value
            )
          `);
      }

      await transaction.commit();

      res.json({ ok: true });

    } catch (err) {
      await transaction.rollback();
      throw err;
    }

  } catch (err) {
    next(err);
  }
});


export default router;