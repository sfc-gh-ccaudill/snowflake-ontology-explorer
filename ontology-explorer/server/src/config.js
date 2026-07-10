import { homedir } from 'node:os';
import { join } from 'node:path';
import { readFileSync, existsSync } from 'node:fs';
import { parse as parseToml } from 'smol-toml';

/**
 * Reads a named connection out of ~/.snowflake/connections.toml.
 *
 * The DEMO connection in this environment uses key-pair auth
 * (authenticator = SNOWFLAKE_JWT + private_key_file), which works for both
 * SQL queries (snowflake-sdk) and for signing the JWT used to call the
 * Cortex Agent REST API.
 */
export function loadConnection() {
  const name = process.env.SNOWFLAKE_CONNECTION_NAME || 'DEMO';
  const tomlPath =
    process.env.SNOWFLAKE_CONNECTIONS_TOML ||
    join(homedir(), '.snowflake', 'connections.toml');

  if (!existsSync(tomlPath)) {
    throw new Error(
      `connections.toml not found at ${tomlPath}. Set SNOWFLAKE_CONNECTIONS_TOML to point at it.`
    );
  }

  const parsed = parseToml(readFileSync(tomlPath, 'utf8'));
  const conn = parsed[name];
  if (!conn) {
    const available = Object.keys(parsed).filter((k) => typeof parsed[k] === 'object');
    throw new Error(
      `Connection "${name}" not found in ${tomlPath}. Available: ${available.join(', ') || '(none)'}`
    );
  }

  // Normalize the fields we care about. Values not present are left undefined.
  return {
    name,
    account: conn.account,
    user: conn.user,
    role: conn.role,
    warehouse: conn.warehouse,
    database: conn.database,
    schema: conn.schema,
    host: conn.host,
    region: conn.region,
    authenticator: conn.authenticator,
    privateKeyPath: conn.private_key_file,
    privateKeyPass: conn.private_key_file_pwd,
    password: conn.password,
  };
}

/** Resolve the account hostname used for REST calls (Cortex Agent). */
export function resolveHost(conn) {
  if (conn.host) return conn.host;
  // Fall back to the standard <account>.snowflakecomputing.com form.
  return `${String(conn.account).replace(/_/g, '-').toLowerCase()}.snowflakecomputing.com`;
}
