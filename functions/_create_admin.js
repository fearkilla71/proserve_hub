// One-off script: creates admins/{uid} doc in Firestore via REST API
// using the Firebase CLI's cached refresh token.

const https = require('https');
const path = require('path');

const PROJECT_ID = 'proserve-hub-ada0e';
const UID = 'NnxXDtRHbqODCPfd9WXCVHzoTk63';

async function getAccessToken() {
  const configPath = path.join(
    process.env.USERPROFILE || process.env.HOME || '',
    '.config', 'configstore',
    'firebase-tools.json'
  );
  const config = require(configPath);
  const refreshToken = config.tokens?.refresh_token;
  if (!refreshToken) throw new Error('No refresh token. Run: firebase login');

  const postData = new URLSearchParams({
    grant_type: 'refresh_token',
    refresh_token: refreshToken,
    client_id: '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
  }).toString();

  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'oauth2.googleapis.com',
      path: '/token',
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Content-Length': Buffer.byteLength(postData),
      },
    }, (res) => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => {
        const j = JSON.parse(body);
        if (j.access_token) resolve(j.access_token);
        else reject(new Error('Token exchange failed: ' + body));
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function createAdminDoc() {
  const token = await getAccessToken();
  console.log('Got access token, writing to Firestore...');

  const docData = JSON.stringify({
    fields: {
      role: { stringValue: 'super_admin' },
      email: { stringValue: 'francocarvic@gmail.com' },
      createdAt: { timestampValue: new Date().toISOString() },
    }
  });

  return new Promise((resolve, reject) => {
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: `/v1/projects/${PROJECT_ID}/databases/(default)/documents/admins/${UID}`,
      method: 'PATCH',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(docData),
      },
    }, (res) => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => {
        if (res.statusCode === 200) {
          console.log(`Created admins/${UID} with role=super_admin`);
          resolve();
        } else {
          console.error(`HTTP ${res.statusCode}: ${body}`);
          reject(new Error(`HTTP ${res.statusCode}`));
        }
      });
    });
    req.on('error', reject);
    req.write(docData);
    req.end();
  });
}

createAdminDoc().then(() => process.exit(0)).catch(e => {
  console.error('Failed:', e.message);
  process.exit(1);
});
