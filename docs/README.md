# GitHub Pages Setup Instructions

This folder contains the HTML files that will be displayed on GitHub Pages. Follow these steps to configure your GitHub repository to serve these files:

1. Go to your GitHub repository page
2. Click on "Settings" (tab at the top of the repository)
3. Scroll down to the "GitHub Pages" section
4. Under "Source", select "Deploy from a branch"
5. Under "Branch", select "main" (or "master" if that's your default branch) and "/docs" folder
6. Click "Save"

After a few minutes, your site will be published at: `https://[your-username].github.io/people_over_parking_2025/`

## What's Included

- `index.html`: A redirect page that points to the main analysis
- `parking_minimums_map.html`: The knitted R Markdown analysis with interactive maps

## Updating the Site

To update the site after making changes to the R Markdown file:

1. Make your changes to `parking_minimums_map.Rmd`
2. Knit the file to HTML using:
   ```r
   rmarkdown::render('parking_minimums_map.Rmd', output_dir = 'docs')
   ```
   Or from the command line:
   ```bash
   Rscript -e "rmarkdown::render('parking_minimums_map.Rmd', output_dir = 'docs')"
   ```
3. Commit and push the changes to GitHub
4. GitHub Pages will automatically update with your changes
