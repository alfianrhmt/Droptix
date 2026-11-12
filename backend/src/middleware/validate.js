'use strict';

const { Errors } = require('../utils/errors');

/**
 * Middleware validasi Zod untuk body, query, atau params.
 */
function validate(schema, target = 'body') {
  return (req, _res, next) => {
    const result = schema.safeParse(req[target]);
    if (!result.success) {
      const details = result.error.issues.map((issue) => ({
        field: issue.path.join('.') || target,
        message: issue.message,
      }));
      return next(Errors.validation('Data tidak valid', details));
    }
    req[target] = result.data;
    return next();
  };
}

module.exports = { validate };

