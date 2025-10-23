walker supervisor {
    can run_python_clone;

    has repo_url;

    # Start of workflow
    can start {
        std.out("=== Codebase Genius Supervisor ===");
        repo_url = std.input("Enter GitHub repo URL: ");
        result = run_python_clone(repo_url);
        std.out(result);
    }
}

walker run_python_clone {
    can run_python;

    has repo_url;

    can run_python(repo_url) {
        py_call("python_helpers.clone_repo.clone_repo", repo_url) -> result;
        return result;
    }
}
