const express = require('express');
const app = express();

app.use(express.json());

//enable CORS for local testing
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  next();
});


// logger
app.use((req, res, next) => {
  console.log(`${req.method} ${req.url}`);
  // response logger
  const originalSend = res.send;
  res.send = function (body) {
    console.log(`Response: ${res.statusCode} ${body}`);
    return originalSend.call(this, body);
  };
  next();
});

// 🔐 Your DRM keys
const KID = "0123456789abcdef0123456789abcdef";
const KEY = "abcdefabcdefabcdefabcdefabcdefab";

app.post('/license', validateToken, (req, res) => {
  // get type from query param
  const type = req.query.type;
  console.log(`License request for type: ${type}`);
  let response;
  // ClearKey license format
  if (type === 'clearkey') {
    response = {
      keys: [
        {
          kty: "oct",
          kid: toBase64Url(KID),
          k: toBase64Url(KEY)
        }
      ],
      type: "temporary"
    };
  } else if (type === 'widevine') {
    // Widevine license format (simplified for demo)
    response = {
      license: toBase64Url(KEY)
    };
  } else {
    return res.status(400).json({ error: 'Unknown license type' });
  }

  res.json(response);
});

app.get('/', (req, res) => {
  res.send('License server is running');
});

app.listen(3000, () => {
  console.log('License server running on http://localhost:3000');
});


function toBase64Url(hex) {
  return Buffer.from(hex, 'hex')
    .toString('base64')
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/, '');
}


// validate token middleware
function validateToken(req, res, next) {
  const token = req.query.token; // for simplicity & ios phones doesn't support attaching headers using shaka.networking interceptors, we use query param instead of header
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }
  
  if (token !== 'correct') {
    return res.status(403).json({ error: 'Invalid token' });
  }

  next();
}