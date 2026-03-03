const fs = require('fs');
const path = require('path');

const docs = [
    'd:/Project/15_SafeTrip_New/Master_docs/36_T2_API_명세서_Part1.md',
    'd:/Project/15_SafeTrip_New/Master_docs/37_T2_API_명세서_Part2.md',
    'd:/Project/15_SafeTrip_New/Master_docs/38_T2_API_명세서_Part3.md'
];

docs.forEach(doc => {
    if (fs.existsSync(doc)) {
        const lines = fs.readFileSync(doc, 'utf8').split('\n');
        lines.forEach(line => {
            if (line.match(/#+\s+\[(GET|POST|PUT|PATCH|DELETE)\]/)) {
                console.log(line.trim());
            }
        });
    }
});
