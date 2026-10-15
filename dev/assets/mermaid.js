document.addEventListener("DOMContentLoaded", async () => {
    const blocks = document.querySelectorAll("pre code.language-mermaid");
    if (blocks.length === 0) return;
    mermaid.initialize({ startOnLoad: false, securityLevel: "strict", theme: "default" });
    const diagrams = Array.from(blocks, (block) => {
        const diagram = document.createElement("div");
        diagram.className = "mermaid";
        diagram.textContent = block.textContent;
        block.parentElement.replaceWith(diagram);
        return diagram;
    });
    await mermaid.run({ nodes: diagrams });
});
