/* eslint-disable max-len */
import {Request, Response} from "express";
import {onRequest} from "firebase-functions/v2/https";
import {initializeApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";
import {SessionsClient, protos} from "@google-cloud/dialogflow-cx";

const projectID = process.env.DIALOGFLOW_PROJECT_ID || ""; // Directly use your Project ID
const agentID = process.env.DIALOGFLOW_AGENT_ID;
const location = process.env.DIALOGFLOW_LOCATION || "global";

initializeApp();

const dialogflowClient = new SessionsClient({
  projectID: projectID,
  apiEndpoint: "asia-southeast1-dialogflow.googleapis.com",
});

// Take the text parameter passed to this HTTP endpoint and insert it into
// Firestore under the path /messages/:documentId/original
exports.addmessage = onRequest(async (req: Request, res: Response) => {
  // Grab the text parameter.
  const original = req.query.text;
  // Push the new message into Firestore using the Firebase Admin SDK.
  const writeResult = await getFirestore()
    .collection("messages")
    .add({original: original});
  // Send back a message that we've successfully written the message
  res.json({result: `Message with ID: ${writeResult.id} added.`});
});

// Test Function, sends a message to the user when
// he make a request to this endpoint
exports.sendMessage = onRequest(async (req: Request, res: Response) => {
  const message = "Hello Ahmad";

  res.json({message: message});
});

exports.diagoniseCrop = onRequest(async (req: Request, res: Response) => {
  try {
    const {imageUrl, imagePath, cropType, userId} = req.body;
    const resolvedImageUrl =
      imageUrl ?? `https://firebasestorage.googleapis.com/v0/b/${process.env.STORAGE_BUCKET}/o/${encodeURIComponent(imagePath)}?alt=media`;
    // API Call - mock for now-
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

    const uid = userId ?? "unknownUser";
    await getFirestore()
      .collection("users").doc(uid)
      .collection("diagnoses")
      .add({
        imageUrl: resolvedImageUrl,
        cropType,
        disease,
        confidence,
        advice,
        submittedAt: Timestamp.now(),
      });
    await getFirestore()
      .collection("users")
      .doc(userId)
      .collection("messages")
      .add({
        sender: "assistant",
        content: `Hi! I’ve just diagnosed your crop.
          It seems to be affected by ${disease}.
          I’m here to help — ask me anything about the treatment or symptoms!`,
        timestamp: Timestamp.now(),
      });
    res.json({disease, confidence, advice});
  } catch (err) {
    console.error("Error: ", err);
  }
});

export const dialogflowWebhook = onRequest(async (req: Request, res: Response) => {
  try {
    const tag = req.body.fulfillmentInfo?.tag;
    const sessionParams = req.body.sessionInfo?.parameters || {};
    const crop = sessionParams.crop;
    const disease = sessionParams.disease;

    let responseText = "Hmm, I’m not sure how to help with that.";

    if (tag === "treatment") {
      const doc = await getFirestore().collection("treatments").doc(disease).get();
      responseText = doc.exists ? doc.data()?.text : "Sorry, no treatment found.";
    } else if (tag === "symptoms") {
      const doc = await getFirestore().collection("symptoms").doc(disease).get();
      responseText = doc.exists ? doc.data()?.text : "Sorry, no symptoms found.";
    } else if (tag === "general_tips") {
      const doc = await getFirestore().collection("generalTips").doc(crop).get();
      responseText = doc.exists ? doc.data()?.text : "Sorry, no tips available.";
    }
    res.json({
      fulfillment_response: {
        messages: [
          {
            text: {
              text: [responseText],
            },
          },
        ],
      },
    });
  } catch (error) {
    console.error("Error handling the webhook: ", error);
    res.status(500).send("Internal Server Error");
  }
});


export const initializeDialogflowSession = onRequest(async (req: Request, res: Response) => {
  try {
    const {sessionId, crop, disease} = req.body;

    if (!sessionId || !crop || !disease) {
      res.status(400).send("Missing required fields: sessionId, crop, or disease");
      return;
    }

    if (!agentID || !location) {
      console.error("Missing required environment variables for Dialogflow (agent ID or location).");
      res.status(500).send("Internal server error: Dialogflow configuration missing.");
      return;
    }

    // Proper session path construction
    const sessionPath = dialogflowClient.projectLocationAgentSessionPath(
      projectID,
      location,
      agentID,
      sessionId
    );

    const parameters = {
      fields: {
        crop: {stringValue: crop},
        disease: {stringValue: disease},
      },
    };

    const request: protos.google.cloud.dialogflow.cx.v3beta1.IDetectIntentRequest = {
      session: sessionPath,
      queryInput: {
        text: {
          text: "hi",
        },
        languageCode: "en",
      },
      queryParams: {
        parameters: parameters,
      },
    };

    const responses = await dialogflowClient.detectIntent(request);
    const [response] = responses;

    console.log("Detected intent:", response);
    res.status(200).json({
      message: "Dialogflow session initialized successfully",
      data: response,
    });
  } catch (error) {
    console.error("Error initializing Dialogflow session: ", error);
    res.status(500).send(`Internal server error: ${error}`);
  }
});
