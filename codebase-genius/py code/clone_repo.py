from git import Repo
import os

def clone_repo(repo_url, output_dir="cloned_repos"):
    repo_name = repo_url.split("/")[-1].replace(".git", "")
    target_path = os.path.join(output_dir, repo_name)

    os.makedirs(output_dir, exist_ok=True)

    if os.path.exists(target_path):
        return f"Repo '{repo_name}' already exists at {target_path}"

    try:
        Repo.clone_from(repo_url, target_path)
        return f"Repository cloned successfully to {target_path}"
    except Exception as e:
        return f"Error cloning repository: {str(e)}"
