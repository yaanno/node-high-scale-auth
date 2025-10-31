#!/usr/bin/env node

/**
 * Bcrypt Hash Generator
 * Generates proper bcrypt hashes for demo users
 */

const bcrypt = require("bcrypt")

const COST_FACTOR = 10

const users = [
  { username: "alice", password: "password123" },
  { username: "bob", password: "securepass456" },
  { username: "admin", password: "adminpass789" },
]

console.log("==========================================")
console.log("Generating bcrypt hashes (cost factor: 10)")
console.log("==========================================\n")

async function generateHashes() {
  console.log("INSERT INTO users (username, password_hash) VALUES")

  for (let i = 0; i < users.length; i++) {
    const { username, password } = users[i]
    const hash = await bcrypt.hash(password, COST_FACTOR)

    const comma = i < users.length - 1 ? "," : ";"
    console.log(`    -- ${username} / ${password}`)
    console.log(`    ('${username}', '${hash}')${comma}`)
    console.log("")
  }

  console.log("==========================================")
  console.log("Verification Test:")
  console.log("==========================================\n")

  // Verify the hashes work
  for (const { username, password } of users) {
    const hash = await bcrypt.hash(password, COST_FACTOR)
    const isValid = await bcrypt.compare(password, hash)
    const status = isValid ? "✓" : "✗"
    console.log(
      `${status} ${username}: Hash ${isValid ? "verified" : "FAILED"}`
    )
  }

  console.log("\n==========================================")
  console.log("Copy the INSERT statement above into:")
  console.log("database/02-seed.sql")
  console.log("==========================================")
}

generateHashes().catch(console.error)
