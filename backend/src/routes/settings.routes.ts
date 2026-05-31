import { Router } from 'express';
import { getPool, sql } from '../db/sql';

const router = Router();

router.get('/', async (_req, res, next) => {
  try {
    const pool = await getPool();

    const globalVars = await pool.request().query(`
      SELECT
        id,
        var_key,
        CASE 
          WHEN is_secret = 1 THEN '********'
          ELSE var_value
        END AS var_value,
        is_secret,
        description,
        created_at,
        updated_at
      FROM dbo.GlobalVariables
      ORDER BY var_key
    `);

    res.json({
      globalVars: globalVars.recordset
    });
  } catch (err) {
    next(err);
  }
});

router.post('/global-variables', async (req, res, next) => {
  try {
    const body = req.body || {};
    const variables = Array.isArray(body.variables) ? body.variables : [];

    const pool = await getPool();

    for (const item of variables) {
      const id = item.id ? Number(item.id) : null;
      const varKey = String(item.var_key || item.key || '').trim();
      const varValue = item.var_value ?? item.value ?? '';
      const isSecret = item.is_secret ? 1 : 0;
      const description = item.description || null;

      if (!varKey) continue;

      if (id) {
        await pool.request()
          .input('id', sql.Int, id)
          .input('var_key', sql.NVarChar(150), varKey)
          .input('var_value', sql.NVarChar(sql.MAX), String(varValue))
          .input('is_secret', sql.Bit, isSecret)
          .input('description', sql.NVarChar(500), description)
          .query(`
            UPDATE dbo.GlobalVariables
            SET
              var_key = @var_key,
              var_value = CASE
                WHEN is_secret = 1 AND @var_value = '********' THEN var_value
                ELSE @var_value
              END,
              is_secret = @is_secret,
              description = @description,
              updated_at = GETDATE()
            WHERE id = @id
          `);
      } else {
        await pool.request()
          .input('var_key', sql.NVarChar(150), varKey)
          .input('var_value', sql.NVarChar(sql.MAX), String(varValue))
          .input('is_secret', sql.Bit, isSecret)
          .input('description', sql.NVarChar(500), description)
          .query(`
            INSERT INTO dbo.GlobalVariables (
              var_key,
              var_value,
              is_secret,
              description
            )
            VALUES (
              @var_key,
              @var_value,
              @is_secret,
              @description
            )
          `);
      }
    }

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

router.delete('/global-variables/:id', async (req, res, next) => {
  try {
    const pool = await getPool();

    await pool.request()
      .input('id', sql.Int, Number(req.params.id))
      .query(`
        DELETE FROM dbo.GlobalVariables
        WHERE id = @id
      `);

    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
});

export default router;