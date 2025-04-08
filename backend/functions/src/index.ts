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

// --- Get the uploaded image and interact with the model AI to diagonise it then save the diagonise in database ---
exports.diagoniseCrop = onRequest({secrets: ["GEMINI_APIKEY"]}, async (req: Request, res: Response) => {
  try {
    const {imageUrl, imagePath, cropType, userId} = req.body;
    const resolvedImageUrl =
      imageUrl ?? `https://firebasestorage.googleapis.com/v0/b/${process.env.STORAGE_BUCKET}/o/${encodeURIComponent(imagePath)}?alt=media`;

    // -- ML Model API Call - mock for now-
    const disease = "rice_brownSpot";
    const confidence = 0.91;

    const snapshot = await getFirestore().collection("diseases").get();
    snapshot.forEach((doc) => console.log("Found doc ID:", doc.id));

    const adviceDoc = await getFirestore()
      .collection("diseases")
      .doc(disease)
      .get();

    let advice = "No advice found.";

    if (adviceDoc.exists) {
      const data = adviceDoc.data();

      advice = data?.treatment || "Treatment information not available.";
    }

    console.log("Advice: ", advice);

    // -- Save Diagnosis to Firestore
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

    // -- Add Initial Assistant Message to Chat History
    const initialMessageContent = `Hi! I’ve diagnosed your crop with ${disease} (Confidence: ${Math.round(confidence * 100)}%).\n\nInitial suggestion: ${advice}\n\nI’m here to help further. Ask me anything about treatment options, symptoms, or prevention!`;

    await getFirestore()
      .collection("diagnoses")
      .doc(diagnosisId)
      .collection("messages")
      .add({
        sender: "assistant",
        content: initialMessageContent,
        timestamp: Timestamp.now(),
      });
    res.json({
      diagnosisId: diagnosisId,
      disease: disease,
      confidence: confidence,
      advice: advice,
    });
  } catch (err) {
    logger.error("Error in diagoniseCrop function:", err);
    res.status(500).json({error: "An internal server error occurred during diagnosis.", details: err});
  }
});

exports.handleChatMessage = onRequest({secrets: ["GEMINI_APIKEY"]}, async (req: Request, res: Response) => {
  try {
    const {userId, diagnosisId, userMessage} = req.body;

    if (!userId || !diagnosisId || !userMessage) {
      res.status(400).json({error: "Missing required fields: userId, diagnosisId, userMessage"});
    }
    if (typeof userMessage !== "string" || userMessage.trim().length === 0) {
      res.status(400).json({error: "User message cannot be empty."});
    }

    // -- Get Diagnosis Context (Disease Name, Initial Advice)
    const diagnosisRef = getFirestore().collection("diagnoses").doc(diagnosisId);
    const diagnosisSnap = await diagnosisRef.get();
    if (!diagnosisSnap.exists) {
      res.status(404).json({error: "Diagnosis context not found. Cannot start chat."});
    }
    const diagnosisData = diagnosisSnap.data();

    if (diagnosisData?.userId !== userId) {
      res.status(403).json({error: "Access denied to this diagnosis chat."});
    }
    const disease = diagnosisData?.disease;
    const initialAdvice = diagnosisData?.advice;
    if (!disease) {
      res.status(500).json({error: "Internal error: Diagnosis context is incomplete."});
    }

    const messagesCollectionRef = diagnosisRef.collection("messages");

    const userMessageData = {
      sender: "user",
      content: userMessage,
      timestamp: Timestamp.now(),
    };
    await messagesCollectionRef.add(userMessageData);

    // -- Prepare Chat History for Gemini
    const model = getGeminiModel();

    const historyQuery = messagesCollectionRef.orderBy("timestamp", "desc").limit(10);
    const historySnap = await historyQuery.get();
    const chatHistoryForGemini = historySnap.docs.map((doc) => {
      const data = doc.data();
      return {
        role: data.sender === "user" ? "user" : "model",
        parts: [{text: data.content}],
      };
    }).reverse();
    // -- Construct Prompt & Call Gemini
    // System instruction to guide Gemini's persona and focus
    const systemInstruction = `You are LeafLyzer, a helpful assistant focused on plant health. The user is asking about a crop diagnosed with ${disease}. Provide advice, answer questions about symptoms, treatment, and prevention related specifically to ${disease}. Keep responses concise and practical for a farmer or gardener. The initial advice given was: "${initialAdvice}". Use the provided chat history for context, don't answer to user responses if they are not related to agriculture at all`;

    const fullHistoryForGemini = [
      // Add the system instruction as the first 'user' message
      {role: "user", parts: [{text: systemInstruction}]},
      // Add a simple 'model' response acknowledging the instruction. This helps prime the model.
      {role: "model", parts: [{text: `Understood. I will act as LeafLyzer and provide information about ${disease}, considering the initial advice was "${initialAdvice}". How can I help?`}]},
      // Append the actual recent chat history retrieved from Firestore
      ...chatHistoryForGemini,
    ];
    const chat = model.startChat({
      // Use the combined history that now includes the system instruction
      history: fullHistoryForGemini,
      generationConfig: {temperature: 0.7, maxOutputTokens: 500},
    });

    const result = await chat.sendMessage(userMessage);

    const geminiResponse = result.response;
    const geminiResponseText = geminiResponse.text();

    // -- Check for Safety Blocks

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
        // Return the safe response to the user
        res.json({reply: blockedMessage});
      }
      // Handle other non-STOP reasons if necessary
      throw new Error("Gemini generation stopped unexpectedly. Finish reason: " + geminiResponse.candidates?.[0]?.finishReason);
    }
    logger.info(`Received Gemini response for diagnosis ${diagnosisId}`, {userId});

    // -- Save Gemini Response

    const assistantMessageData = {
      sender: "assistant",
      content: geminiResponseText,
      timestamp: Timestamp.now(),
    };
    await messagesCollectionRef.add(assistantMessageData);

    // --- Send Response to Client ---

    res.json({reply: geminiResponseText});
  } catch (err: unknown) {
    let errorMessage = "An unknown error occurred while handling the chat message.";
    if (err instanceof Error) {
      logger.error("Error in handleChatMessage function:", err);
      errorMessage = `An internal server error occurred: ${err.message}`;
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
