"""
Utility functions for Codebase Genius
These Python functions will be called from Jac code
"""

import os
import shutil
from git import Repo
from pathlib import Path
import re


def clone_repository(repo_url, target_dir):
    """
    Clone a GitHub repository to a local directory
    
    Args:
        repo_url: GitHub repository URL
        target_dir: Local directory to clone into
        
    Returns:
        dict with 'success' (bool) and 'message' (str)
    """
    try:
        # Clean up if directory already exists
        if os.path.exists(target_dir):
            shutil.rmtree(target_dir)
        
        # Create parent directory
        os.makedirs(os.path.dirname(target_dir), exist_ok=True)
        
        # Clone the repository
        Repo.clone_from(repo_url, target_dir)
        
        return {
            'success': True,
            'message': f'Successfully cloned to {target_dir}'
        }
    except Exception as e:
        return {
            'success': False,
            'message': f'Error cloning repository: {str(e)}'
        }


def build_file_tree(root_path):
    """
    Build a tree structure of files in the repository
    
    Args:
        root_path: Root directory of the repository
        
    Returns:
        dict mapping file paths to file types
    """
    file_tree = {}
    
    # Directories to ignore
    ignore_dirs = {
        '.git', 'node_modules', '__pycache__', 'venv', '.venv',
        'env', 'build', 'dist', '.eggs', '*.egg-info', '.tox',
        '.pytest_cache', '.mypy_cache', 'htmlcov', '.coverage'
    }
    
    # File extensions to include
    code_extensions = {
        '.py': 'python',
        '.jac': 'jac',
        '.js': 'javascript',
        '.ts': 'typescript',
        '.java': 'java',
        '.cpp': 'cpp',
        '.c': 'c',
        '.h': 'c',
        '.go': 'go',
        '.rs': 'rust',
        '.rb': 'ruby',
        '.php': 'php',
    }
    
    for root, dirs, files in os.walk(root_path):
        # Remove ignored directories from traversal
        dirs[:] = [d for d in dirs if d not in ignore_dirs and not d.startswith('.')]
        
        for file in files:
            # Skip hidden files
            if file.startswith('.'):
                continue
                
            file_path = os.path.join(root, file)
            relative_path = os.path.relpath(file_path, root_path)
            
            # Get file extension
            _, ext = os.path.splitext(file)
            
            if ext in code_extensions:
                file_tree[relative_path] = code_extensions[ext]
            elif file.lower() in ['readme.md', 'readme.txt', 'readme']:
                file_tree[relative_path] = 'readme'
            elif ext == '.md':
                file_tree[relative_path] = 'markdown'
    
    return file_tree


def read_file(file_path):
    """
    Read content of a file
    
    Args:
        file_path: Path to the file
        
    Returns:
        dict with 'success' (bool) and 'content' (str) or 'error' (str)
    """
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        return {
            'success': True,
            'content': content
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }


def extract_repo_name(repo_url):
    """
    Extract repository name from GitHub URL
    
    Args:
        repo_url: GitHub repository URL
        
    Returns:
        Repository name string
    """
    # Remove .git suffix if present
    url = repo_url.rstrip('/')
    if url.endswith('.git'):
        url = url[:-4]
    
    # Get last part of URL
    parts = url.split('/')
    return parts[-1] if parts else 'unknown-repo'


def simple_parse_python(content):
    """
    Simple Python parser using regex (fallback if tree-sitter fails)
    
    Args:
        content: Python file content
        
    Returns:
        dict with 'functions' and 'classes' lists
    """
    functions = []
    classes = []
    
    lines = content.split('\n')
    
    for i, line in enumerate(lines):
        # Find function definitions
        func_match = re.match(r'^def\s+(\w+)\s*\(', line)
        if func_match:
            func_name = func_match.group(1)
            
            # Try to get docstring
            docstring = ""
            if i + 1 < len(lines):
                next_line = lines[i + 1].strip()
                if next_line.startswith('"""') or next_line.startswith("'''"):
                    docstring = next_line.strip('"""').strip("'''")
            
            functions.append({
                'name': func_name,
                'line': i + 1,
                'docstring': docstring,
                'type': 'function'
            })
        
        # Find class definitions
        class_match = re.match(r'^class\s+(\w+)', line)
        if class_match:
            class_name = class_match.group(1)
            
            # Try to get docstring
            docstring = ""
            if i + 1 < len(lines):
                next_line = lines[i + 1].strip()
                if next_line.startswith('"""') or next_line.startswith("'''"):
                    docstring = next_line.strip('"""').strip("'''")
            
            classes.append({
                'name': class_name,
                'line': i + 1,
                'docstring': docstring,
                'type': 'class'
            })
    
    return {
        'functions': functions,
        'classes': classes
    }


def find_function_calls(content, function_name):
    """
    Find all calls to a specific function
    
    Args:
        content: Source code content
        function_name: Name of function to find calls for
        
    Returns:
        List of line numbers where function is called
    """
    calls = []
    lines = content.split('\n')
    
    pattern = re.compile(rf'\b{function_name}\s*\(')
    
    for i, line in enumerate(lines):
        if pattern.search(line):
            calls.append(i + 1)
    
    return calls


def get_readme_summary(root_path, max_length=500):
    """
    Find and read README file
    
    Args:
        root_path: Root directory of repository
        max_length: Maximum length of summary
        
    Returns:
        README content or default message
    """
    readme_files = ['README.md', 'readme.md', 'README.txt', 'README', 'readme']
    
    for readme_file in readme_files:
        readme_path = os.path.join(root_path, readme_file)
        if os.path.exists(readme_path):
            result = read_file(readme_path)
            if result['success']:
                content = result['content']
                if len(content) > max_length:
                    return content[:max_length] + "..."
                return content
    
    return "No README file found in repository."


def save_documentation(output_dir, filename, content):
    """
    Save generated documentation to a file
    
    Args:
        output_dir: Output directory
        filename: Name of the file
        content: Documentation content
        
    Returns:
        dict with 'success' (bool) and 'path' (str) or 'error' (str)
    """
    try:
        # Create output directory
        os.makedirs(output_dir, exist_ok=True)
        
        # Full file path
        file_path = os.path.join(output_dir, filename)
        
        # Write content
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return {
            'success': True,
            'path': file_path
        }
    except Exception as e:
        return {
            'success': False,
            'error': str(e)
        }


def count_lines(file_path):
    """
    Count lines in a file
    
    Args:
        file_path: Path to file
        
    Returns:
        Number of lines or 0 if error
    """
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            return len(f.readlines())
    except:
        return 0