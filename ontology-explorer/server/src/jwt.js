import { readFileSync } from 'node:fs';
import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';

/**
 * Generates a Snowflake key-pair JWT for calling REST APIs (e.g. Cortex Agent).
 *
 * Reference: the JWT's issuer is
 *   <ACCOUNT>.<USER>.SHA256:<base64 fingerprint of the DER public key>
 * and the subject is <ACCOUNT>.<USER>, both uppercased, with any region/cloud
 * suffix stripped from the account.
 */
export function generateJwt(conn) {
  if (!conn.privateKeyPath) {
    throw new Error('Key-pair JWT requires private_key_file in the connection.');
  }

  const pem = readFileSync(conn.privateKeyPath, 'utf8');
  const privateKey = crypto.createPrivateKey({
    key: pem,
    passphrase: conn.privateKeyPass || undefined,
  });

  // Fingerprint = SHA256 over the DER-encoded SubjectPublicKeyInfo, base64.
  const publicKeyDer = crypto
    .createPublicKey(privateKey)
    .export({ type: 'spki', format: 'der' });
  const fingerprint =
    'SHA256:' + crypto.createHash('sha256').update(publicKeyDer).digest('base64');

  const account = String(conn.account).split('.')[0].toUpperCase();
  const user = String(conn.user).toUpperCase();
  const qualifiedUser = `${account}.${user}`;

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: `${qualifiedUser}.${fingerprint}`,
    sub: qualifiedUser,
    iat: now,
    exp: now + 3600,
  };

  return jwt.sign(payload, privateKey, { algorithm: 'RS256' });
}
