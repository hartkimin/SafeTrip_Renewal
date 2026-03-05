const fs = require('fs');
const path = require('path');

function walkDir(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        file = path.join(dir, file);
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) {
            results = results.concat(walkDir(file));
        } else {
            if (file.endsWith('.controller.ts')) {
                results.push(file);
            }
        }
    });
    return results;
}

const srcDir = path.join(__dirname, 'src');
const files = walkDir(srcDir);

files.forEach(file => {
    const content = fs.readFileSync(file, 'utf8');
    let baseRoute = '';
    const controllerMatch = content.match(/@Controller\(['"](.*?)['"]\)/);
    if (controllerMatch) {
        baseRoute = controllerMatch[1];
    }

    const methodRegex = /@(Get|Post|Put|Delete|Patch)\(['"]([^'"]*)['"]\)?/g;
    let match;
    while ((match = methodRegex.exec(content)) !== null) {
        const httpMethod = match[1].toUpperCase();
        let subRoute = match[2] || '';
        if (subRoute.startsWith('/')) subRoute = subRoute.substring(1);

        let fullRoute = `/${baseRoute}`;
        if (subRoute) fullRoute += `/${subRoute}`;

        fullRoute = fullRoute.replace(/\/+/g, '/');
        console.log(`[${httpMethod}] ${fullRoute} (${path.basename(file)})`);
    }
});
