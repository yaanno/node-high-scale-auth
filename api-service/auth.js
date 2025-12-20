// middleware/auth.js
import pkg  from 'jsonwebtoken';
const { verify } = pkg;

export default function(req, res, next) {
  const auth = req.headers['authorization'];
  if (!auth) return res.status(401).send('no token');

  const token = auth.replace(/^Bearer\s+/i, '');
  verify(token, process.env.JWT_SECRET, {
    issuer: 'auth-service',
    audience: 'api-service',
    clockTolerance: 30
  }, (err, payload) => {
    if (err) return res.status(401).send('invalid token');
    req.user = { id: payload.sub, claims: payload };
    next();
  });
};
