import {Request, Response} from "express";
// The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.

import {onRequest} from "firebase-functions/v2/https";

// The Firebase Admin SDK to access Firestore.
import {initializeApp} from "firebase-admin/app";
import {getFirestore, Timestamp} from "firebase-admin/firestore";

initializeApp();

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
    const prediction = "rice_brownSpot";
    const confidence = 0.91;

    console.log("Getting diseases collection....");
    const snapshot = await getFirestore().collection("diseases").get();
    console.log("Number of documents:", snapshot.size);
    snapshot.forEach((doc) => console.log("Found doc ID:", doc.id));

    const adviceDoc = await getFirestore()
      .collection("diseases")
      .doc(prediction)
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
        prediction,
        confidence,
        advice,
        submittedAt: Timestamp.now(),
      });
    res.json({prediction, confidence, advice});
  } catch (err) {
    console.error("Error: ", err);
  }
});

exports.dialogflowWebhook = onRequest(async (req: Request, res: Response) => {
  try {
    const intentName = req.body.queryResult.intent.displayName;

    if (intentName === "AfterDiagnosis-Help") {
      res.json({
        fulfillmentText: "Here’s the advice for treating your crop disease...",
      });
    }

    if (intentName === "SymptomsExplanation") {
      const disease = req.body.queryResult.parameters.disease;
      const doc =
        await getFirestore().collection("diseases").doc(disease).get();

      if (doc.exists) {
        const symptoms = doc.data()?.symptoms || "No symptoms data found.";
        res.json({
          fulfillmentText: `Symptoms of ${disease}: ${symptoms}`,
        });
      }
      res.json({
        fulfillmentText: `Sorry, I couldn’t find information on ${disease}.`,
      });
    }

    if (intentName === "TreatmentDetails") {
      const prediction = req.body.queryResult.parameters.disease;
      const doc =
        await getFirestore().collection("diseases").doc(prediction).get();

      if (doc.exists) {
        const adviceDoc = await getFirestore()
          .collection("diseases")
          .doc(prediction)
          .get();


        let advice = "No advice found."; // Default value

        if (adviceDoc.exists) {
          const data = adviceDoc.data();

          advice = data?.treatment || "Treatment information not available.";
        }
        res.json({
          fulfillmentText: `Treatment for ${prediction}: ${advice}`,
        });
      }
      res.json({
        fulfillmentText:
          `Sorry, I couldn’t find treatment advice for ${prediction}.`,
      });
    }

    res.json({
      fulfillmentText: "Sorry, I didn’t recognize that intent.",
    });
  } catch (err) {
    console.error("Error: ", err);
  }
});


