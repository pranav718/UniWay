import { apiError, badRequest, formatZodError, successResponse, unauthorized, validateBodySize } from "@/lib/api-response";
import { DUMMY_PASSWORD_HASH, signJwt, verifyPassword } from "@/lib/auth";
import { sql } from "@/lib/db";
import { withKeyedRateLimit, withRateLimit } from "@/lib/rate-limit";
import { LoginRequestSchema, UserPublicSchema } from "@/lib/schemas/auth";

export const dynamic = "force-dynamic";

export async function POST(request: Request) {
  const rateLimitResponse = withRateLimit(request, { maxRequests: 10, windowMs: 60_000 });
  if (rateLimitResponse) return rateLimitResponse;

  const sizeCheck = await validateBodySize(request, 10_240);
  if (!sizeCheck.ok) return sizeCheck.response;

  try {
    const rawBody = JSON.parse(sizeCheck.body);
    const parsed = LoginRequestSchema.safeParse(rawBody);
    if (!parsed.success) {
      return badRequest("Validation failed", formatZodError(parsed.error), undefined, request);
    }

  const { email, password } = parsed.data;

  // Complements the per-address limit above: rotating client addresses cannot dodge a
  // per-account cap on credential guessing.
  const accountLimitResponse = withKeyedRateLimit(`login:${email}`, { maxRequests: 8, windowMs: 60_000 });
  if (accountLimitResponse) return accountLimitResponse;

  const rows = await sql`
      SELECT id, email, password_hash, name, avatar_url, auth_provider, created_at
      FROM users
      WHERE lower(email) = ${email}
      LIMIT 1
    `;

    if (!rows.length) {
      // Burn the same scrypt cost as a real check so an unknown email is not observable
      // through response timing.
      await verifyPassword(password, DUMMY_PASSWORD_HASH);
      return unauthorized("Invalid email or password", undefined, request);
    }

    const userRow = rows[0];
    if (!userRow.password_hash) {
      // Generic 401 (not a distinct "registered with Google" response) so the endpoint does
      // not confirm which email addresses hold accounts.
      await verifyPassword(password, DUMMY_PASSWORD_HASH);
      return unauthorized("Invalid email or password", undefined, request);
    }

    const isMatch = await verifyPassword(password, userRow.password_hash);
    if (!isMatch) {
      return unauthorized("Invalid email or password", undefined, request);
    }

    const user = UserPublicSchema.parse(userRow);
    const token = signJwt({ sub: user.id, email: user.email, name: user.name });

    return successResponse({ user, token });
  } catch (error) {
    return apiError(error, "Failed to login user", request);
  }
}
