# GitHub Activity Logger

The GitHub Activity Logger is a Ruby script that fetches recent activities from a GitHub user's account and logs them to a Markdown file.

## Usage

1. Set up your GitHub personal access token and username as environment variables:

   ```bash
   export GITHUB_USERNAME=your_github_username
   export GITHUB_TOKEN=your_github_token
   ```

   Replace `your_github_username` and `your_github_token` with your actual GitHub username and personal access token.

2. Run the script:

   ```bash
   ruby gitlog.rb
   ```

3. The script will fetch recent activities from your GitHub account and log them to a Markdown file named `eod.md`.

## Features

- Logs the following GitHub activities:
  - Pull request reviews
  - Issues opened
  - Pull requests opened
  - Commits pushed to repositories
- Organizes activities by repository and branch

## Dependencies

- `net/http`: Used for making HTTP requests to the GitHub API.
- `json`: Used for parsing JSON responses from the GitHub API.
- `time`: Used for handling time-related operations.

## Contributing

If you encounter any issues or have suggestions for improvements, feel free to [open an issue](https://github.com/bodhish/eod/issues) or [create a pull request](https://github.com/bodhish/eod/pulls).
