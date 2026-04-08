const express = require('express');
const path = require('path');

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

app.get('/', (req, res) => {
  res.send('CDN server is running');
});

app.listen(4000, () => {
  console.log('CDN server running on http://localhost:4000');
});



const VIDEO_DIR = path.join(__dirname, 'storage');

app.get('/:file', validateToken, (req, res) => {
  const file = req.params.file;

  const filePath = path.join(VIDEO_DIR, file);

  console.log('Serving: ', file);

  res.sendFile(filePath);
});

app.get('/live/:file', validateToken, (req, res) => {
  const file = req.params.file;
  // is file .mpd||m4s or .m3u8||.ts
  const type = file.endsWith('.mpd') || file.endsWith('.m4s') ? 'dash' : file.endsWith('.m3u8') || file.endsWith('.ts') ? 'hls' : 'unknown';

  const filePath = path.join(VIDEO_DIR, `live/${type}`, file);

  console.log(`Serving live ${type}: `, file);

  res.sendFile(filePath);
});

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
