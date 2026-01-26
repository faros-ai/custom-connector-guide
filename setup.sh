#!/bin/bash

# Airbyte Custom Connector Setup Script
# This script helps set up the development environment for the JSONPlaceholder connector example

set -e

echo "🚀 Setting up Airbyte Custom Connector Development Environment..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js 22 or later."
    exit 1
fi

echo "✅ Node.js version: $(node --version)"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed. Please install npm."
    exit 1
fi

echo "✅ npm version: $(npm --version)"

# Install dependencies for the source
echo "📦 Installing dependencies for JSONPlaceholder source..."
cd sources/jsonplaceholder-source
npm install

# Build the source
echo "🔨 Building JSONPlaceholder source..."
npm run build

# Go back to guide directory
cd ../..

# Install dependencies for the destination
echo "📦 Installing dependencies for example Faros destination..."
cd destinations/airbyte-faros-destination
npm install

# Build the destination
echo "🔨 Building Faros destination..."
npm run build

cd ../..

echo ""
echo "✅ Setup complete! You can now start developing custom connectors."
echo ""
echo "Next steps:"
echo "1. Test the source: cd sources/jsonplaceholder-source && ../../test-source.sh"
echo "2. Test the converter: ./test-converter.sh"
echo "3. Run end-to-end test: ./run-e2e.sh"
