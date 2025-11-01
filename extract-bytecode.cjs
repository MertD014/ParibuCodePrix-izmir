#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Extract bytecode from compiled Foundry artifacts and save to separate files
 */
function extractBytecode() {
    const outDir = path.join(__dirname, 'out');
    const bytecodeDir = path.join(__dirname, 'bytecode');
    
    // Create bytecode directory if it doesn't exist
    if (!fs.existsSync(bytecodeDir)) {
        fs.mkdirSync(bytecodeDir, { recursive: true });
    }
    
    // Find all car contract directories in out/
    const carDirs = fs.readdirSync(outDir, { withFileTypes: true })
        .filter(dirent => dirent.isDirectory())
        .filter(dirent => dirent.name.includes('Car') || dirent.name.includes('.sol'))
        .map(dirent => dirent.name);
    
    let extractedCount = 0;
    
    carDirs.forEach(carDir => {
        const carPath = path.join(outDir, carDir);
        
        // Look for JSON files in this directory
        const jsonFiles = fs.readdirSync(carPath)
            .filter(file => file.endsWith('.json'));
        
        jsonFiles.forEach(jsonFile => {
            try {
                const jsonPath = path.join(carPath, jsonFile);
                const contractData = JSON.parse(fs.readFileSync(jsonPath, 'utf8'));
                
                // Extract bytecode if it exists
                if (contractData.bytecode && contractData.bytecode.object) {
                    const bytecode = contractData.bytecode.object;
                    
                    // Skip if bytecode is empty or just deployment bytecode placeholder
                    if (bytecode === '0x' || bytecode.length < 10) {
                        console.log(`Skipping ${jsonFile} - empty bytecode`);
                        return;
                    }
                    
                    // Create filename for bytecode
                    const contractName = path.basename(jsonFile, '.json');
                    const bytecodeFileName = `${contractName}.bytecode`;
                    const bytecodeFilePath = path.join(bytecodeDir, bytecodeFileName);
                    
                    // Write bytecode to file
                    fs.writeFileSync(bytecodeFilePath, bytecode);
                    console.log(`Extracted bytecode: ${contractName} -> ${bytecodeFileName}`);
                    extractedCount++;
                    
                    // Also create a metadata file with contract info
                    const metadataFileName = `${contractName}.meta.json`;
                    const metadataFilePath = path.join(bytecodeDir, metadataFileName);
                    
                    const metadata = {
                        contractName,
                        sourceFile: carDir,
                        abi: contractData.abi || [],
                        bytecodeLength: bytecode.length,
                        extractedAt: new Date().toISOString()
                    };
                    
                    fs.writeFileSync(metadataFilePath, JSON.stringify(metadata, null, 2));
                    console.log(`Created metadata: ${metadataFileName}`);
                }
            } catch (error) {
                console.error(`Error processing ${jsonFile}:`, error.message);
            }
        });
    });
    
    console.log(`\nExtraction complete! Processed ${extractedCount} contracts.`);
    console.log(`Bytecode files saved to: ${bytecodeDir}`);
}

// Run the extraction
if (require.main === module) {
    extractBytecode();
}

module.exports = { extractBytecode };