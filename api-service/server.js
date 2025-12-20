// api-service/server.js
import express from "express"
import auth from "./auth.js"
const app = express()
const PORT = process.env.PORT || 3000

// Simple logging middleware
app.use((req, res, next) => {
  console.log(`[API] Received request for: ${req.path}`)
  next()
})

app.use(auth)

// The protected endpoint. Nginx ensures only authorized requests reach here.
app.get("/api/v1/user/profile", (req, res) => {
  // CRITICAL: Read the trusted header injected by Nginx
  const userId = req.user

  if (!userId) {
    // This should theoretically never happen if Nginx config is correct,
    // but it's good defensive programming.
    console.error("[API] ERROR: Missing trusted user identity header")
    return res.status(500).json({ error: "Internal Auth Error" })
  }

  // --- Start of I/O Bound Task (e.g., Database lookup by ID) ---
  // Simulate fetching user data from a database based on the trusted ID
  const userData = {
    id: userId.id,
    lastLogin: new Date().toISOString(),
  }

  // Simulate I/O delay (e.g., 50ms database query)
  setTimeout(() => {
    console.log(`[API] Successfully served profile for user: ${userId.id}`)
    res.json({
      message: "Profile data fetched successfully (I/O operation simulated)",
      data: userData,
      status: "OK",
    })
  }, 50)
})

app.listen(PORT, () => {
  console.log(`[API] Node.js I/O API listening on port ${PORT}`)
})
