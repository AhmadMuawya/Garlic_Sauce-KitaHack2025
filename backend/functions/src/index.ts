/* eslint-disable max-len */
import {Request, Response} from "express";
import {onRequest} from "firebase-functions/v2/https";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {GoogleGenerativeAI} from "@google/generative-ai";
import * as logger from "firebase-functions/logger";

// const projectID = process.env.DIALOGFLOW_PROJECT_ID || "";
// const agentID = process.env.DIALOGFLOW_AGENT_ID;
// const location = process.env.DIALOGFLOW_LOCATION || "global";

let geminiModel: ReturnType<GoogleGenerativeAI["getGenerativeModel"]> | null = null;

const getGeminiModel = () => {
  if (!geminiModel) {
    const GEMINI_API_KEY = process.env.GEMINI_APIKEY || "";
    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
    geminiModel = genAI.getGenerativeModel({model: "gemini-1.5-flash"});
  }
  return geminiModel;
};

initializeApp();

// Take the text parameter passed to this HTTP endpoint and insert it into
// Firestore under the path /messages/:documentId/original
// export const addmessage = onRequest(async (req: Request, res: Response) => {
//   // Grab the text parameter.
//   const original = req.query.text;
//   // Push the new message into Firestore using the Firebase Admin SDK.
//   const writeResult = await getFirestore()
//     .collection("messages")
//     .add({original: original});
//   // Send back a message that we've successfully written the message
//   res.json({result: `Message with ID: ${writeResult.id} added.`});
// });

// Test Function, sends a message to the user when
// he make a request to this endpoint
exports.sendMessage = onRequest(async (req: Request, res: Response) => {
  const message = "Hello Ahmaaaad";

  res.json({message: message});
});

exports.diagoniseCrop = onRequest({secrets: ["GEMINI_APIKEY"]}, async (req: Request, res: Response) => {
  try {
    const {imageUrl, imagePath, cropType, userId} = req.body;
    const resolvedImageUrl =
      imageUrl ?? `https://firebasestorage.googleapis.com/v0/b/${process.env.STORAGE_BUCKET}/o/${encodeURIComponent(imagePath)}?alt=media`;

    // ML Model API Call - mock for now-
    const disease = "rice_brownSpot";
    const confidence = 0.91;

    const snapshot = await getFirestore().collection("diseases").get();
    console.log("Number of documents:", snapshot.size);
    snapshot.forEach((doc) => console.log("Found doc ID:", doc.id));

    const adviceDoc = await getFirestore()
      .collection("diseases")
      .doc(disease)
      .get();

    console.log("Document Exists: ", adviceDoc.exists);
    console.log("Document Data: ", adviceDoc.data());

    let advice = "No advice found."; // Default value

    if (adviceDoc.exists) {
      const data = adviceDoc.data();

      advice = data?.treatment || "Treatment information not available.";
    }

    console.log("Advice: ", advice);

    // --- Save Diagnosis to Firestore ---
    const diagnosisData = {
      imageUrl: resolvedImageUrl,
      cropType: cropType ?? null,
      disease: disease,
      confidence: confidence,
      advice: advice,
      submittedAt: Timestamp.now(),
      userId: userId,
    };

    const diagnosisRef = await getFirestore().collection("diagnoses").add(diagnosisData);
    const diagnosisId = diagnosisRef.id;
    logger.info(`Diagnosis ${diagnosisId} saved for user ${userId}`, {disease, confidence});

    // --- Add Initial Assistant Message to Chat History ---
    const initialMessageContent = `Hi! I’ve diagnosed your crop with *${disease}* (Confidence: ${Math.round(confidence * 100)}%).\n\nInitial suggestion: ${advice}\n\nI’m here to help further. Ask me anything about treatment options, symptoms, or prevention!`;

    await getFirestore()
      .collection("diagnoses")
      .doc(diagnosisId)
      .collection("messages")
      .add({
        sender: "assistant",
        content: initialMessageContent,
        timestamp: Timestamp.now(),
      });
    logger.info(`Initial assistant message saved for diagnosis ${diagnosisId}`, {userId});
    // --- Step 2: Send Response to Client (include diagnosisId) ---
    res.json({
      diagnosisId: diagnosisId, // <<< Include the ID in the response
      disease: disease,
      confidence: confidence,
      advice: advice,
    });

    logger.info(`Sent response for diagnosis ${diagnosisId} to client`, {userId});
  } catch (err) {
    logger.error("Error in diagoniseCrop function:", err);
    res.status(500).json({error: "An internal server error occurred during diagnosis.", details: err});
  }
});

exports.handleChatMessage = onRequest({secrets: ["GEMINI_APIKEY"]}, async (req: Request, res: Response) => {
  logger.info("handleChatMessage function started", {body: req.body});

  try {
    const {userId, diagnosisId, userMessage} = req.body;

    if (!userId || !diagnosisId || !userMessage) {
      logger.warn("Missing required fields in chat message request", {body: req.body});
      res.status(400).json({error: "Missing required fields: userId, diagnosisId, userMessage"});
    }
    if (typeof userMessage !== "string" || userMessage.trim().length === 0) {
      logger.warn("Invalid userMessage format or empty message", {userId, diagnosisId});
      res.status(400).json({error: "User message cannot be empty."});
    }

    // --- Get Diagnosis Context (Disease Name, Initial Advice) ---
    const diagnosisRef = getFirestore().collection("diagnoses").doc(diagnosisId);
    const diagnosisSnap = await diagnosisRef.get();
    if (!diagnosisSnap.exists) {
      logger.error(`Diagnosis ${diagnosisId} not found for chat request`, {userId});
      res.status(404).json({error: "Diagnosis context not found. Cannot start chat."});
    }
    const diagnosisData = diagnosisSnap.data();

    if (diagnosisData?.userId !== userId) {
      logger.warn(`User ${userId} attempting to access diagnosis ${diagnosisId} owned by ${diagnosisData?.userId}`);
      res.status(403).json({error: "Access denied to this diagnosis chat."});
    }
    const disease = diagnosisData?.disease;
    const initialAdvice = diagnosisData?.advice;
    if (!disease) {
      logger.error(`Disease data missing in diagnosis ${diagnosisId}`);
      res.status(500).json({error: "Internal error: Diagnosis context is incomplete."});
    }
    logger.info(`Context loaded for diagnosis ${diagnosisId}`, {userId, disease});

    // --- Define Message Collection Reference ---
    const messagesCollectionRef = diagnosisRef.collection("messages");

    const userMessageData = {
      sender: "user",
      content: userMessage,
      timestamp: Timestamp.now(),
    };
    await messagesCollectionRef.add(userMessageData);
    logger.info(`User message saved for diagnosis ${diagnosisId}`, {userId});

    // --- Prepare Chat History for Gemini ---
    const model = getGeminiModel();
    // Fetch recent messages (e.g., last 10) to provide context to Gemini
    // Adjust the limit based on desired context length vs. token usage/cost
    const historyQuery = messagesCollectionRef.orderBy("timestamp", "desc").limit(10);
    const historySnap = await historyQuery.get();
    const chatHistoryForGemini = historySnap.docs.map((doc) => {
      const data = doc.data();
      // Map 'sender' ("user" or "assistant") to Gemini's 'role' ("user" or "model")
      return {
        role: data.sender === "user" ? "user" : "model",
        parts: [{text: data.content}],
      };
    }).reverse();
    logger.debug(`Prepared chat history for Gemini (length: ${chatHistoryForGemini.length})`, {diagnosisId, userId});

    // --- Construct Prompt & Call Gemini ---
    // System instruction to guide Gemini's persona and focus
    const systemInstruction = `You are AgriAI, a helpful assistant focused on plant health. The user is asking about a crop diagnosed with *${disease}*. Provide advice, answer questions about symptoms, treatment, and prevention related specifically to *${disease}*. Keep responses concise and practical for a farmer or gardener. The initial advice given was: "${initialAdvice}". Use the provided chat history for context.`;

    const fullHistoryForGemini = [
      // Add the system instruction as the first 'user' message
      {role: "user", parts: [{text: systemInstruction}]},
      // Add a simple 'model' response acknowledging the instruction. This helps prime the model.
      {role: "model", parts: [{text: `Understood. I will act as AgriAI and provide information about ${disease}, considering the initial advice was "${initialAdvice}". How can I help?`}]},
      // Append the actual recent chat history retrieved from Firestore
      ...chatHistoryForGemini,
    ];
    const chat = model.startChat({
      // Use the combined history that now includes the system instruction
      history: fullHistoryForGemini,
      generationConfig: {temperature: 0.7, maxOutputTokens: 500},
    });

    logger.info(`Sending message to Gemini for diagnosis ${diagnosisId}`, {userId, disease});
    // Send the *latest* user message to the ongoing chat session
    // Note: Some models prefer system instructions set differently (e.g., via generateContent parameter)
    // Adapt based on Gemini model documentation if needed.

    const result = await chat.sendMessage(userMessage); // Just send the latest message text

    const geminiResponse = result.response;
    const geminiResponseText = geminiResponse.text();

    // --- Check for Safety Blocks ---

    // See Gemini documentation for finishReason and safetyRatings structure
    if (!geminiResponseText && geminiResponse.candidates?.[0]?.finishReason !== "STOP") {
      logger.warn("Gemini response potentially blocked or empty", {diagnosisId, userId, finishReason: geminiResponse.candidates?.[0]?.finishReason, safetyRatings: geminiResponse.candidates?.[0]?.safetyRatings});
      // Handle safety blocks specifically
      if (geminiResponse.candidates?.[0]?.finishReason === "SAFETY") {
        const blockedMessage = "I cannot provide a response to that specific question due to safety guidelines. Could you please ask something else related to the crop disease?";
        // Save a safe response message
        await messagesCollectionRef.add({
          sender: "assistant",
          content: blockedMessage,
          timestamp: Timestamp.now(),
        });
        logger.info(`Saved safety block message for diagnosis ${diagnosisId}`, {userId});
        // Return the safe response to the user
        res.json({reply: blockedMessage});
      }
      // Handle other non-STOP reasons if necessary
      throw new Error("Gemini generation stopped unexpectedly. Finish reason: " + geminiResponse.candidates?.[0]?.finishReason);
    }
    logger.info(`Received Gemini response for diagnosis ${diagnosisId}`, {userId});

    // --- Save Gemini Response ---

    const assistantMessageData = {
      sender: "assistant",
      content: geminiResponseText,
      timestamp: Timestamp.now(),
    };
    await messagesCollectionRef.add(assistantMessageData);
    logger.info(`Assistant (Gemini) message saved for diagnosis ${diagnosisId}`, {userId});

    // --- Send Response to Client ---

    res.json({reply: geminiResponseText});
  } catch (err: unknown) {
    let errorMessage = "An unknown error occurred while handling the chat message.";
    if (err instanceof Error) {
      logger.error("Error in handleChatMessage function:", err);
      errorMessage = `An internal server error occurred: ${err.message}`;
      // Check specifically for Gemini API errors if needed (consult SDK docs for specific error types/codes)
    } else {
      logger.error("Caught a non-Error object in handleChatMessage:", err);
      errorMessage = "An unexpected error format occurred.";
    }
    res.status(500).json({
      error: "Failed to process chat message.",
      details: errorMessage, // Provide detail from the error message
    });
  }
}
);
