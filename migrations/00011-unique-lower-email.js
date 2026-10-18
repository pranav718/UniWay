export async function up(sql) {
  // The unique constraint on the raw email column is case-sensitive, so "User@x.com" and
  // "user@x.com" could otherwise coexist even though every lookup is case-insensitive.
  // The earlier non-unique lower(email) index is replaced by a unique one, which is what
  // turns a lost registration race into a clean constraint violation instead of a
  // double account (the route maps 23505 to 409).
  await sql`DROP INDEX IF EXISTS users_email_lower_idx`;
  await sql`CREATE UNIQUE INDEX IF NOT EXISTS users_email_lower_unique_idx ON users (lower(email))`;
}

export async function down(sql) {
  await sql`DROP INDEX IF EXISTS users_email_lower_unique_idx`;
  await sql`CREATE INDEX IF NOT EXISTS users_email_lower_idx ON users (lower(email))`;
}
