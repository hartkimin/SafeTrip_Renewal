const fs = require('fs');
const sw = JSON.parse(fs.readFileSync('swagger.json', 'utf8'));

let out = '';

for (const [path, methods] of Object.entries(sw.paths)) {
    if (path.includes('/auth') || path.includes('/users')) {
        out += `\n### Path: ${path}\n`;
        for (const [method, data] of Object.entries(methods)) {
            out += `#### [${method.toUpperCase()}] ${path}\n`;
            out += `**Summary**: ${data.summary || ''}\n`;

            if (data.parameters && data.parameters.length > 0) {
                out += `**Parameters**:\n`;
                for (const p of data.parameters) {
                    out += `- ${p.name} (${p.in}): ${p.schema?.type || 'unknown'}\n`;
                }
            }
            out += '\n';
        }
    }
}

fs.writeFileSync('generated-api-specs-part1.md', out);
