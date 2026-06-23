import { createAccessToken } from 'ridi-backends/apps/test/utils';
import { getUserTokenUUID } from 'ridi-backends/apps/utils/auth/userToken';
import rootConfig from 'ridi-backends/config';
import { end, knexRaw, ridiPrimary } from 'ridi-backends/db';
import { unixTimestamp } from 'ridi-backends/utils';

const USER_ID = 'localstamp';
const EMAIL = 'localstamp@example.com';
const TOKEN_TTL_SECONDS = 60 * 60;

async function main() {
  await ridiPrimary('bom', 'tb_user')
    .insert({
      id: USER_ID,
      name: '로컬스탬프',
      email: EMAIL,
      ip: '127.0.0.1',
      device_id: '',
      gender: '',
      status: 'NORMAL',
      email_verify_date: knexRaw('NOW()'),
    })
    .onConflict('id')
    .ignore();

  const user = await ridiPrimary('bom', 'tb_user')
    .select('idx', 'id', 'email')
    .where('id', USER_ID)
    .first();

  if (!user) {
    throw new Error(`Local login user not found: ${USER_ID}`);
  }

  await ridiPrimary('account', 'oauth2_user')
    .insert({
      id: 1,
      name: 'local-oauth',
      created: knexRaw('NOW()'),
      last_modified: knexRaw('NOW()'),
    })
    .onConflict('id')
    .ignore();

  await ridiPrimary('account', 'oauth2_application')
    .insert({
      name: 'local-ridi',
      oauth2_user_id: 1,
      client_id: rootConfig.clientId.ridi,
      redirect_uris: '',
      client_secret: 'local-secret',
      skip_authorization: 1,
      client_type: 'confidential',
      authorization_grant_type: 'password',
      is_in_house: 1,
    })
    .onConflict('client_id')
    .ignore();

  const userTokenUUID = await getUserTokenUUID(Number(user.idx));
  const at = createAccessToken({
    userId: USER_ID,
    userIdx: Number(user.idx),
    userTokenUUID,
    exp: unixTimestamp() + TOKEN_TTL_SECONDS,
  });

  console.log(JSON.stringify({ user, userTokenUUID, at }));
}

main()
  .then(async () => {
    await end();
    process.exit(0);
  })
  .catch(async error => {
    console.error(error);
    await end();
    process.exit(1);
  });
