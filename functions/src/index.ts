/**
 * Firebase Cloud Function (v2)
 * Auto-reply assistant for dementia patients.
 * Compatible with firebase-functions v2+.
 */

import { onValueCreated } from "firebase-functions/v2/database";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";
import fetch from "cross-fetch";

// Initialize Firebase Admin SDK
admin.initializeApp();

const ASSISTANT_ID = "assistant_bot";

// 🔹 Main Function (v2 syntax)
export const onNewPatientMessage = onValueCreated(
  "/chats/{uid}/messages/{msgId}",
  async (event) => {
    const snapshot = event.data;
    const msg = snapshot?.val();
    const uid = event.params.uid;

    if (!msg || msg.senderId === ASSISTANT_ID) return;

    const userText: string = msg.text || "";
    if (!userText.trim()) return;

    const replyText = await generateReply(userText);

    const messagesRef = snapshot?.ref.parent; // /chats/{uid}/messages
    await messagesRef?.push({
      senderId: ASSISTANT_ID,
      text: replyText,
      emotion: detectEmotion(replyText),
      timestamp: new Date().toISOString(),
    });

    logger.info(`🤖 Assistant replied to ${uid}: ${replyText}`);
  }
);

// 🔹 Generate a smart or fallback reply
async function generateReply(userText: string): Promise<string> {
  const apiKey = process.env.OPENAI_API_KEY;

  // If no OpenAI key, use local fallback
  if (!apiKey) return ruleBasedReply(userText);

  try {
    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-4o-mini",
        messages: [
          {
            role: "system",
            content:
              "You are a kind, supportive AI assistant for dementia patients. Respond simply, calmly, and with reassurance.",
          },
          { role: "user", content: userText },
        ],
        temperature: 0.6,
        max_tokens: 100,
      }),
    });

    const data = await response.json();
    const aiResponse = data?.choices?.[0]?.message?.content?.trim();

    return aiResponse || ruleBasedReply(userText);
  } catch (error) {
    logger.error("⚠️ OpenAI error:", error);
    return ruleBasedReply(userText);
  }
}

// 🔹 Local fallback if AI API isn’t configured
function ruleBasedReply(userText: string): string {
  const t = userText.toLowerCase();

  if (t.includes("hello") || t.includes("hi"))
    return "Hello! How are you feeling today?";
  if (t.includes("medicine"))
    return "Please remember to take your medicine 💊.";
  if (t.includes("food") || t.includes("hungry"))
    return "Let’s have a light meal 🍲.";
  if (t.includes("sad") || t.includes("tired"))
    return "I’m here for you 💙. Let’s take a deep breath together.";
  if (t.includes("happy"))
    return "That’s wonderful! Keep smiling 😊.";
  if (t.includes("who am i"))
    return "You’re safe at home. I’m your assistant here to help you.";
  if (t.includes("time") || t.includes("date")) {
    const now = new Date();
    return `It’s ${now.toLocaleTimeString()} on ${now.toLocaleDateString()}.`;
  }
  return "I’m listening carefully. How do you feel?";
}

// 🔹 Emotion detection helper
function detectEmotion(text: string): string {
  const t = text.toLowerCase();
  if (t.includes("wonderful") || t.includes("happy")) return "happy";
  if (t.includes("sorry") || t.includes("tired")) return "sad";
  return "";
}
