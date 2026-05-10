import { google } from 'googleapis';
import * as readline from 'readline';

const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
const clientSecret = process.env.GOOGLE_OAUTH_CLIENT_SECRET;
const redirectUri =
  process.env.GOOGLE_OAUTH_REDIRECT_URI ||
  'https://developers.google.com/oauthplayground';

if (!clientId || !clientSecret) {
  throw new Error('Faltan GOOGLE_OAUTH_CLIENT_ID o GOOGLE_OAUTH_CLIENT_SECRET');
}

const oauth2Client = new google.auth.OAuth2(
  clientId,
  clientSecret,
  redirectUri,
);

const authUrl = oauth2Client.generateAuthUrl({
  access_type: 'offline',
  prompt: 'consent',
  scope: [
    'https://www.googleapis.com/auth/drive',
    'https://www.googleapis.com/auth/calendar',
  ],
});

console.log('\nAbre esta URL:\n');
console.log(authUrl);

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

rl.question('\nPega el code aqui: ', (code) => {
  void (async () => {
    try {
      const { tokens } = await oauth2Client.getToken(code.trim());

      console.log('\nAccess token:\n', tokens.access_token);
      console.log('\nRefresh token:\n', tokens.refresh_token);
      console.log('\nExpiry date:\n', tokens.expiry_date);
    } catch (error) {
      console.error(error);
    } finally {
      rl.close();
    }
  })();
});
