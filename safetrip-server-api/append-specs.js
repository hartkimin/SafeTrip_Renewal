const fs = require('fs');
const path = require('path');

const targetFile = 'd:\\Project\\15_SafeTrip_New\\Master_docs\\37_T2_API_명세서_Part2.md';
let content = fs.readFileSync(targetFile, 'utf8');

const generatedSpecs = fs.readFileSync('generated-api-specs.md', 'utf8');

// The file ends at around line 800 with "### §6.F 출석체크". 
// I will append the generated API specs at the end of the file under a new section.

const appendData = `\n\n---\n\n## §7 Trips, Guardians, Locations, Geofences\n\n` + generatedSpecs + `\n`;
fs.appendFileSync(targetFile, appendData);

console.log('Appended generated API specs to 37_T2_API_명세서_Part2.md');
