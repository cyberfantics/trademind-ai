const express = require("express");
const cors = require("cors");
const dotenv = require("dotenv");

const { initializeApp, cert, getApps } = require("firebase-admin/app");
const { getAuth } = require("firebase-admin/auth");


dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

const MAX_QUESTION_LENGTH = 2000;
const MAX_JOURNAL_ENTRIES = 80;
const MAX_CHAT_HISTORY_MESSAGES = 12;
const MAX_CHAT_MESSAGE_LENGTH = 1800;

const DAILY_AI_LIMIT = 5;

app.use(
  cors({
    origin: process.env.ALLOWED_ORIGIN || "*",
    methods: ["GET", "POST", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.use(
  express.json({
    limit: "2mb",
  })
);

function getServiceAccountFromEnv() {
  const serviceAccountBase64 = process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;

  if (!serviceAccountBase64) {
    throw new Error("Server Firebase configuration is missing.");
  }

  try {
    const serviceAccountJson = Buffer.from(
      serviceAccountBase64,
      "base64"
    ).toString("utf8");

    const serviceAccount = JSON.parse(serviceAccountJson);

    if (!serviceAccount.project_id) {
      throw new Error("Firebase service account project_id is missing.");
    }

    if (!serviceAccount.client_email) {
      throw new Error("Firebase service account client_email is missing.");
    }

    if (!serviceAccount.private_key) {
      throw new Error("Firebase service account private_key is missing.");
    }

    return serviceAccount;
  } catch (error) {
    throw new Error("Server Firebase configuration is invalid.");
  }
}

function initFirebaseAdmin() {
  const apps = getApps();

  if (apps.length > 0) {
    return apps[0];
  }

  const serviceAccount = getServiceAccountFromEnv();

  return initializeApp({
    credential: cert(serviceAccount),
  });
}

function getUtcDateKey() {
  return new Date().toISOString().slice(0, 10);
}

function getNextUtcResetIso() {
  const now = new Date();

  const nextReset = new Date(
    Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate() + 1,
      0,
      0,
      0,
      0
    )
  );

  return nextReset.toISOString();
}

async function checkAndConsumeDailyAiLimit(uid) {
  const firebaseApp = initFirebaseAdmin();
  const db = getFirestore(firebaseApp);

  const dateKey = getUtcDateKey();

  const ref = db
    .collection("aiRateLimits")
    .doc(uid)
    .collection("daily")
    .doc(dateKey);

  return await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);

    const currentCount = snapshot.exists
      ? Number(snapshot.data().count || 0)
      : 0;

    if (currentCount >= DAILY_AI_LIMIT) {
      const error = new Error(
        `Daily AI limit reached. You can ask ${DAILY_AI_LIMIT} questions per day.`
      );

      error.statusCode = 429;
      error.remaining = 0;
      error.limit = DAILY_AI_LIMIT;
      error.resetAt = getNextUtcResetIso();

      throw error;
    }

    const nextCount = currentCount + 1;

    transaction.set(
      ref,
      {
        uid,
        dateKey,
        count: nextCount,
        limit: DAILY_AI_LIMIT,
        updatedAt: FieldValue.serverTimestamp(),
        createdAt: snapshot.exists
          ? snapshot.data().createdAt || FieldValue.serverTimestamp()
          : FieldValue.serverTimestamp(),
      },
      {
        merge: true,
      }
    );

    return {
      limit: DAILY_AI_LIMIT,
      used: nextCount,
      remaining: Math.max(DAILY_AI_LIMIT - nextCount, 0),
      resetAt: getNextUtcResetIso(),
    };
  });
}

function getBearerToken(req) {
  const authHeader = req.headers.authorization || "";

  if (!authHeader.startsWith("Bearer ")) {
    return null;
  }

  return authHeader.replace("Bearer ", "").trim();
}

async function verifyFirebaseUser(req) {
  const token = getBearerToken(req);

  if (!token) {
    const error = new Error("Authentication token is missing.");
    error.statusCode = 401;
    throw error;
  }

  const firebaseApp = initFirebaseAdmin();

  try {
    const decodedToken = await getAuth(firebaseApp).verifyIdToken(token);

    return {
      uid: decodedToken.uid,
      email: decodedToken.email || null,
    };
  } catch (_) {
    const error = new Error("Authentication failed. Please login again.");
    error.statusCode = 401;
    throw error;
  }
}

function safeText(value, fallback = "") {
  if (value === null || value === undefined) {
    return fallback;
  }

  return String(value).trim();
}

function safeNumber(value, fallback = 0) {
  const num = Number(value);
  return Number.isFinite(num) ? num : fallback;
}

function limitText(value, maxLength) {
  const text = safeText(value);

  if (text.length <= maxLength) {
    return text;
  }

  return `${text.substring(0, maxLength).trim()}...`;
}


function limitText(value, maxLength) {
  const text = safeText(value);

  if (text.length <= maxLength) {
    return text;
  }

  return `${text.substring(0, maxLength).trim()}...`;
}

function buildPreviousContextContext(previousContext) {
  if (!previousContext || typeof previousContext !== "object") {
    return "No previous question and answer context.";
  }

  const previousQuestion = limitText(previousContext.question, 1000);
  const previousAnswer = limitText(previousContext.answer, 1800);

  if (!previousQuestion && !previousAnswer) {
    return "No previous question and answer context.";
  }

  return `
Previous user question:
${previousQuestion || "Not available"}

Previous AI answer:
${previousAnswer || "Not available"}
`;
}


function buildJournalContext(entries) {
  if (!Array.isArray(entries) || entries.length === 0) {
    return "No journal entries were sent for this message.";
  }

  const cleanEntries = entries.slice(0, MAX_JOURNAL_ENTRIES);

  const wins = cleanEntries.filter((entry) => entry.isWin === true).length;
  const losses = cleanEntries.filter((entry) => entry.isLoss === true).length;

  const totalPnl = cleanEntries.reduce((sum, entry) => {
    return sum + safeNumber(entry.pnlAmount);
  }, 0);

  const winRate =
    cleanEntries.length === 0 ? 0 : (wins / cleanEntries.length) * 100;

  const recentTrades = cleanEntries
    .map((entry, index) => {
      return `
Trade ${index + 1}:
Pair: ${safeText(entry.pair, "Unknown")}
Side: ${safeText(entry.side, "Unknown")}
Entry: ${safeNumber(entry.entryPrice)}
Exit: ${safeNumber(entry.exitPrice)}
Leverage: ${safeNumber(entry.leverage)}x
Position Size: ${safeNumber(entry.positionSize)}
PnL Percent: ${safeNumber(entry.pnlPercent).toFixed(2)}%
PnL Amount: ${safeNumber(entry.pnlAmount).toFixed(2)}
Setup: ${safeText(entry.setup, "Not written") || "Not written"}
Emotion: ${safeText(entry.emotion, "Not written") || "Not written"}
Notes: ${safeText(entry.notes, "Not written") || "Not written"}
Date: ${safeText(entry.createdAt, "Unknown") || "Unknown"}
`;
    })
    .join("\n---\n");

  return `
Summary:
Total trades received: ${cleanEntries.length}
Wins: ${wins}
Losses: ${losses}
Win rate: ${winRate.toFixed(2)}%
Total PnL amount: ${totalPnl.toFixed(2)}

Recent trades:
${recentTrades}
`;
}

function buildPrompt({ question, journalEntries, previousContext, user }) {
  const hasJournalData =
    Array.isArray(journalEntries) && journalEntries.length > 0;

  const journalContext = hasJournalData
    ? buildJournalContext(journalEntries)
    : "Journal data was not sent for this follow-up message.";

  const previousContextText = buildPreviousContextContext(previousContext);

  return `
You are a trading journal coach inside a trader app.

Authenticated Firebase user ID:
${user.uid}

Response rules:
- Do not introduce yourself.
- Do not mention the app name unless the user asks.
- Do not write unnecessary introduction.
- Answer the user's latest question directly.
- Use previous question and previous answer for context.
- Keep continuity with the previous answer.
- Do not repeat the same full analysis again unless the user asks.
- Give a complete answer, not a half answer.
- Use simple and clear language.
- Use short sections with headings.
- Use bullet points where helpful.
- Do not promise profit.
- Do not give guaranteed financial advice.
- Give educational trading journal analysis only.
- If data is missing, clearly say what data is missing.
- If the user asks something that needs fresh journal data and journal data was not sent, tell them to refresh journal analysis first.

Latest user question:
${question}

Previous context:
${previousContextText}

Journal data:
${journalContext}

Important:
- If journal data is present, analyze from it.
- If journal data is not present, answer as a follow-up using previous context.
- Do not invent trades, PnL, emotions, setups, or results that are not in the provided data or previous context.

Now give a complete and useful answer.
`;
}

function extractGeminiAnswer(data) {
  const parts = data?.candidates?.[0]?.content?.parts;

  if (!Array.isArray(parts) || parts.length === 0) {
    return "";
  }

  return parts
    .map((part) => part?.text || "")
    .filter((text) => text.trim().length > 0)
    .join("\n")
    .trim();
}

app.get("/", (req, res) => {
  return res.status(200).json({
    success: true,
    message: "TradeMind AI backend is running.",
    routes: {
      health: "/health",
      geminiJournal: "/api/gemini-journal",
    },
  });
});

app.get("/health", (req, res) => {
  return res.status(200).json({
    success: true,
    status: "ok",
  });
});

app.post("/api/gemini-journal", async (req, res) => {
  try {
    const apiKey = process.env.GEMINI_API_KEY;
    const model = process.env.GEMINI_MODEL || "gemini-2.5-flash";

    if (!apiKey) {
      return res.status(500).json({
        success: false,
        error: "AI server configuration is missing.",
      });
    }

    const user = await verifyFirebaseUser(req);

    const rateLimit = await checkAndConsumeDailyAiLimit(user.uid);

    const question = safeText(req.body?.question);

    const journalEntries = Array.isArray(req.body?.journalEntries)
      ? req.body.journalEntries
      : [];

    const previousContext =
  req.body?.previousContext && typeof req.body.previousContext === "object"
    ? req.body.previousContext
    : null;
    
    const chatHistory = Array.isArray(req.body?.chatHistory)
      ? req.body.chatHistory
      : [];

    if (!question) {
      return res.status(400).json({
        success: false,
        error: "Question is required.",
      });
    }

    if (question.length > MAX_QUESTION_LENGTH) {
      return res.status(400).json({
        success: false,
        error: `Question is too long. Maximum ${MAX_QUESTION_LENGTH} characters allowed.`,
      });
    }

    const prompt = buildPrompt({
  question,
  journalEntries,
  previousContext,
  user,
});

    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        systemInstruction: {
          parts: [
            {
              text:
                "You are a responsible trading journal coach. Answer directly and completely. Do not add unnecessary app introductions. Use simple language. Give educational analysis only. No profit guarantees.",
            },
          ],
        },
        contents: [
          {
            role: "user",
            parts: [
              {
                text: prompt,
              },
            ],
          },
        ],
        generationConfig: {
          temperature: 0.45,
          maxOutputTokens: 2500,
        },
      }),
    });

    let data;

    try {
      data = await geminiResponse.json();
    } catch (_) {
      return res.status(502).json({
        success: false,
        error: "AI returned an invalid response.",
      });
    }

    if (!geminiResponse.ok) {
      return res.status(geminiResponse.status).json({
        success: false,
        error: "AI request failed. Please try again.",
      });
    }

    const answer = extractGeminiAnswer(data);
    const finishReason = data?.candidates?.[0]?.finishReason || null;

    if (!answer) {
      return res.status(502).json({
        success: false,
        error: "AI returned an empty answer.",
      });
    }

    return res.status(200).json({
  success: true,
  finishReason,
  rateLimit,
  answer:
    finishReason === "MAX_TOKENS"
      ? `${answer}\n\nNote: The answer was cut because it reached the output limit. Please ask again with a more specific question.`
      : answer,
});
    
  } catch (error) {
  return res.status(error.statusCode || 500).json({
    success: false,
    error: error.message || "Server error. Please try again.",
    rateLimit:
      error.statusCode === 429
        ? {
            limit: error.limit,
            remaining: error.remaining,
            resetAt: error.resetAt,
          }
        : undefined,
  });
}
});

app.use((req, res) => {
  return res.status(404).json({
    success: false,
    error: "Route not found.",
  });
});

app.listen(PORT, () => {});
