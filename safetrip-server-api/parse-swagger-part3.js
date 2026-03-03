const fs = require('fs');
const sw = JSON.parse(fs.readFileSync('swagger.json', 'utf8'));

let out = '';

for (const [path, methods] of Object.entries(sw.paths)) {
    if (path.includes('/emergencies') || path.includes('/chats') || path.includes('/fcm') || path.includes('/payments') || path.includes('/b2b') || path.includes('/countries') || path.includes('/guides') || path.includes('/events') || path.includes('/mofa')) {
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

fs.writeFileSync('generated-api-specs-part3.md', out);
