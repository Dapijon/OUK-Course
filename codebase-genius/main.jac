"""
Codebase Genius - Main Entry Point
Version 1: Simple but functional implementation
"""

import:py os;
import:py json;
import:py from utils.repo_utils, *;

# =============================================================================
# NODES - Data structures representing entities
# =============================================================================

node Repository {
    has url: str;
    has name: str;
    has local_path: str = "";
    has file_tree: dict = {};
    has readme_summary: str = "";
    has total_files: int = 0;
    has status: str = "initialized";
}

node CodeFile {
    has file_path: str;
    has language: str;
    has content: str = "";
    has functions: list = [];
    has classes: list = [];
    has line_count: int = 0;
    has analyzed: bool = False;
}

node Documentation {
    has repo_name: str;
    has content: str = "";
    has output_path: str = "";
    has generated: bool = False;
}

# =============================================================================
# EDGES - Relationships between nodes
# =============================================================================

edge contains;      # Repository contains CodeFiles
edge documents;     # Documentation documents Repository

# =============================================================================
# WALKER 1: Code Genius (Supervisor)
# Entry point that orchestrates the entire workflow
# =============================================================================

walker CodeGenius {
    has repo_url: str;
    has output_dir: str = "./outputs";
    
    can start with `root entry {
        print("\n" + "="*60);
        print("🧠 CODEBASE GENIUS - AI Documentation Generator");
        print("="*60);
        print(f"📦 Repository: {self.repo_url}");
        print("="*60 + "\n");
        
        # Extract repository name
        repo_name = extract_repo_name(self.repo_url);
        
        # Create repository node
        repo_node = here ++> Repository(
            url=self.repo_url,
            name=repo_name
        );
        
        # Visit the repository node to start processing
        visit [-->](`?Repository);
    }
    
    can orchestrate with Repository entry {
        print("🎯 Starting orchestration...\n");
        
        # Update status
        here.status = "cloning";
        
        # Spawn RepoMapper to handle cloning and mapping
        spawn RepoMapper(repo=here) on here;
    }
}

# =============================================================================
# WALKER 2: Repo Mapper
# Clones repository and creates file structure map
# =============================================================================

walker RepoMapper {
    has repo: Repository;
    
    can map with Repository entry {
        print("🗺️  REPO MAPPER: Starting repository mapping...");
        
        # Set up local path
        local_path = f"./temp/{here.name}";
        here.local_path = local_path;
        
        # Clone the repository
        print(f"   📥 Cloning repository to {local_path}...");
        clone_result = clone_repository(here.url, local_path);
        
        if not clone_result['success'] {
            print(f"   ❌ Error: {clone_result['message']}");
            here.status = "failed";
            return;
        }
        
        print(f"   ✅ {clone_result['message']}");
        
        # Build file tree
        print("   📂 Building file tree...");
        here.file_tree = build_file_tree(local_path);
        here.total_files = len(here.file_tree);
        print(f"   ✅ Found {here.total_files} files");
        
        # Get README summary
        print("   📄 Reading README...");
        here.readme_summary = get_readme_summary(local_path);
        print(f"   ✅ README loaded ({len(here.readme_summary)} characters)");
        
        here.status = "mapped";
        print("   ✨ Repository mapping complete!\n");
        
        # Now spawn CodeAnalyzer
        spawn CodeAnalyzer(repo=here) on here;
    }
}

# =============================================================================
# WALKER 3: Code Analyzer
# Analyzes code files and extracts structure
# =============================================================================

walker CodeAnalyzer {
    has repo: Repository;
    
    can analyze with Repository entry {
        print("🔍 CODE ANALYZER: Starting code analysis...");
        
        if here.status != "mapped" {
            print("   ⚠️  Repository not mapped yet");
            return;
        }
        
        # Filter code files (Python and Jac)
        code_files = [
            (path, lang) 
            for path, lang in here.file_tree.items() 
            if lang in ['python', 'jac']
        ];
        
        print(f"   📊 Analyzing {len(code_files)} code files...");
        
        analyzed_count = 0;
        
        # Analyze each code file
        for file_path, language in code_files {
            full_path = os.path.join(here.local_path, file_path);
            
            # Read file content
            read_result = read_file(full_path);
            
            if read_result['success'] {
                content = read_result['content'];
                
                # Parse the file
                if language == 'python' {
                    parse_result = simple_parse_python(content);
                    functions = parse_result['functions'];
                    classes = parse_result['classes'];
                } else {
                    # For Jac files, we'll do basic parsing
                    functions = [];
                    classes = [];
                }
                
                # Create CodeFile node
                file_node = here ++> CodeFile(
                    file_path=file_path,
                    language=language,
                    content=content,
                    functions=functions,
                    classes=classes,
                    line_count=len(content.split('\n')),
                    analyzed=True
                );
                
                analyzed_count += 1;
                
                if len(functions) > 0 or len(classes) > 0 {
                    print(f"   ✓ {file_path}: {len(functions)} functions, {len(classes)} classes");
                }
            }
        }
        
        here.status = "analyzed";
        print(f"   ✅ Analyzed {analyzed_count} files\n");
        
        # Now spawn DocGenie to generate documentation
        spawn DocGenie(repo=here) on here;
    }
}

# =============================================================================
# WALKER 4: Doc Genie
# Generates final markdown documentation
# =============================================================================

walker DocGenie {
    has repo: Repository;
    
    can generate with Repository entry {
        print("📝 DOC GENIE: Generating documentation...");
        
        if here.status != "analyzed" {
            print("   ⚠️  Code analysis not complete yet");
            return;
        }
        
        # Build the markdown documentation
        markdown = self.build_markdown(here);
        
        # Create documentation node
        doc_node = here ++> Documentation(
            repo_name=here.name,
            content=markdown,
            generated=True
        );
        
        # Save to file
        output_dir = f"./outputs/{here.name}";
        save_result = save_documentation(output_dir, "docs.md", markdown);
        
        if save_result['success'] {
            doc_node[0].output_path = save_result['path'];
            print(f"   ✅ Documentation saved to: {save_result['path']}");
        } else {
            print(f"   ❌ Error saving: {save_result['error']}");
        }
        
        here.status = "complete";
        
        print("\n" + "="*60);
        print("✨ DOCUMENTATION GENERATION COMPLETE!");
        print("="*60);
        print(f"📊 Statistics:");
        print(f"   - Total files: {here.total_files}");
        print(f"   - Documentation length: {len(markdown)} characters");
        print(f"   - Output: {save_result['path'] if save_result['success'] else 'N/A'}");
        print("="*60 + "\n");
        
        report {
            "status": "success",
            "repo_name": here.name,
            "output_path": save_result['path'] if save_result['success'] else None,
            "total_files": here.total_files,
            "doc_length": len(markdown)
        };
    }
    
    can build_markdown(repo: Repository) -> str {
        """Build comprehensive markdown documentation"""
        
        md = f"# {repo.name}\n\n";
        md += f"*Generated by Codebase Genius*\n\n";
        md += "---\n\n";
        
        # Overview section
        md += "## 📋 Overview\n\n";
        md += f"{repo.readme_summary}\n\n";
        
        # Repository information
        md += "## 📊 Repository Information\n\n";
        md += f"- **Repository URL**: {repo.url}\n";
        md += f"- **Total Files**: {repo.total_files}\n";
        
        # Count file types
        file_types = {};
        for lang in repo.file_tree.values() {
            file_types[lang] = file_types.get(lang, 0) + 1;
        }
        
        md += f"- **Languages Detected**: {', '.join(file_types.keys())}\n\n";
        
        # File breakdown
        md += "### File Breakdown\n\n";
        for lang, count in file_types.items() {
            md += f"- {lang}: {count} files\n";
        }
        md += "\n";
        
        # Repository structure
        md += "## 📂 Repository Structure\n\n";
        md += "```\n";
        
        # Sort files for better readability
        sorted_files = sorted(repo.file_tree.keys());
        for file_path in sorted_files {
            md += f"{file_path}\n";
        }
        md += "```\n\n";
        
        # Code analysis section
        md += "## 🔍 Code Analysis\n\n";
        
        # Get all code file nodes
        code_files = [n for n in [-->](`?CodeFile) if n.analyzed];
        
        if len(code_files) > 0 {
            # Python files
            python_files = [f for f in code_files if f.language == 'python'];
            
            if len(python_files) > 0 {
                md += "### Python Files\n\n";
                
                for file in python_files {
                    if len(file.functions) > 0 or len(file.classes) > 0 {
                        md += f"#### `{file.file_path}`\n\n";
                        md += f"*{file.line_count} lines of code*\n\n";
                        
                        # Classes
                        if len(file.classes) > 0 {
                            md += "**Classes:**\n";
                            for cls in file.classes {
                                md += f"- `{cls['name']}` (line {cls['line']})";
                                if cls.get('docstring') {
                                    md += f": {cls['docstring']}";
                                }
                                md += "\n";
                            }
                            md += "\n";
                        }
                        
                        # Functions
                        if len(file.functions) > 0 {
                            md += "**Functions:**\n";
                            for func in file.functions {
                                md += f"- `{func['name']}()` (line {func['line']})";
                                if func.get('docstring') {
                                    md += f": {func['docstring']}";
                                }
                                md += "\n";
                            }
                            md += "\n";
                        }
                    }
                }
            }
            
            # Jac files
            jac_files = [f for f in code_files if f.language == 'jac'];
            if len(jac_files) > 0 {
                md += "### Jac Files\n\n";
                for file in jac_files {
                    md += f"- `{file.file_path}` ({file.line_count} lines)\n";
                }
                md += "\n";
            }
        } else {
            md += "*No code files analyzed*\n\n";
        }
        
        # Installation section
        md += "## 🚀 Installation\n\n";
        md += "```bash\n";
        md += f"# Clone the repository\n";
        md += f"git clone {repo.url}\n\n";
        md += f"# Navigate to the project\n";
        md += f"cd {repo.name}\n\n";
        md += f"# Install dependencies (if applicable)\n";
        md += f"pip install -r requirements.txt  # For Python projects\n";
        md += "```\n\n";
        
        # Usage section
        md += "## 💻 Usage\n\n";
        md += "*Refer to the repository's README for specific usage instructions.*\n\n";
        
        # Footer
        md += "---\n\n";
        md += "*This documentation was automatically generated by Codebase Genius.*\n";
        
        return md;
    }
}

# =============================================================================
# MAIN ENTRY POINT (for testing)
# =============================================================================

with entry {
    # Create root node
    root_node = here;
    
    # Example: Analyze a sample repository
    # Replace this with your target repository
    test_repo = "https://github.com/python/cpython.git";
    
    # Start Code Genius
    spawn CodeGenius(
        repo_url=test_repo
    ) on root_node;
}