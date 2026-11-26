#!/usr/bin/env bash
# Seeds a small Express app. The new download route skips the auth middleware every
# other route uses, and joins a query parameter straight into a file path.
set -euo pipefail
mkdir -p src/routes src/middleware uploads

cat > src/middleware/auth.js <<'EOF'
// Rejects requests without a valid session.
function requireAuth(req, res, next) {
  if (!req.session || !req.session.userId) return res.status(401).json({ error: 'unauthorized' });
  next();
}

module.exports = { requireAuth };
EOF

cat > src/routes/projects.js <<'EOF'
const express = require('express');
const { requireAuth } = require('../middleware/auth');
const router = express.Router();

router.get('/projects', requireAuth, async (req, res) => {
  res.json(await req.db.projects.forUser(req.session.userId));
});

module.exports = router;
EOF

cat > src/routes/files.js <<'EOF'
const express = require('express');
const path = require('path');
const router = express.Router();

const UPLOAD_DIR = path.join(__dirname, '..', '..', 'uploads');

router.get('/files', require('../middleware/auth').requireAuth, async (req, res) => {
  res.json(await req.db.files.forUser(req.session.userId));
});

// NEW: download a file by name
router.get('/files/download', (req, res) => {
  const filePath = path.join(UPLOAD_DIR, req.query.name);
  res.download(filePath);
});

module.exports = router;
EOF

cat > src/app.js <<'EOF'
const express = require('express');
const session = require('express-session');
const app = express();

app.use(session({ secret: process.env.SESSION_SECRET, resave: false, saveUninitialized: false }));
app.use(require('./routes/projects'));
app.use(require('./routes/files'));

module.exports = app;
EOF
