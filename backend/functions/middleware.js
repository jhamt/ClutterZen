"use strict";

const admin = require("firebase-admin");

/**
 * Authentication middleware for Firebase Functions
 * Verifies Firebase Auth ID token from request headers
 * 
 * Usage:
 * app.get("/protected-route", authenticate, (req, res) => {
 *   const uid = req.user.uid;
 *   // ... handler code
 * });
 */
const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({error: "Authorization header missing or invalid"});
    }

    const idToken = authHeader.split("Bearer ")[1];
    
    try {
      const decodedToken = await admin.auth().verifyIdToken(idToken);
      req.user = decodedToken; // Attach user info to request
      next();
    } catch (error) {
      console.error("Token verification failed:", error);
      return res.status(401).json({error: "Invalid or expired token"});
    }
  } catch (error) {
    console.error("Authentication middleware error:", error);
    return res.status(500).json({error: "Authentication failed"});
  }
};

/**
 * Optional authentication middleware
 * Attaches user info if token is present, but doesn't require it
 * 
 * Usage:
 * app.get("/optional-auth-route", optionalAuthenticate, (req, res) => {
 *   if (req.user) {
 *     // User is authenticated
 *   } else {
 *     // User is not authenticated, but route is still accessible
 *   }
 * });
 */
const optionalAuthenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (authHeader && authHeader.startsWith("Bearer ")) {
      const idToken = authHeader.split("Bearer ")[1];
      try {
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        req.user = decodedToken;
      } catch (error) {
        // Token invalid, but continue without user
        req.user = null;
      }
    } else {
      req.user = null;
    }
    
    next();
  } catch (error) {
    req.user = null;
    next();
  }
};

module.exports = {
  authenticate,
  optionalAuthenticate,
};

