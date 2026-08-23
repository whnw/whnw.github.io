To create a GitHub Pages repository for a user site, follow these steps:

Create a new repository:

Go to your GitHub profile.
Click the "+" icon in the top-right corner and select "New repository".
Name the repository as whnw.github.io.
Initialize the repository:

You can choose to add a README file, a .gitignore, or a license if you want.
Click "Create repository".
Add content to your site:

Clone the repository to your local machine:
git clone https://github.com/whnw/whnw.github.io.git
Add your HTML, CSS, and JavaScript files to the repository.
Push the changes to GitHub:

Code
git add .
git commit -m "Initial commit"
git push origin main
Visit your site:

Go to https://whnw.github.io to see your website live.

When you encounter the error "Key is already in use" while adding a new SSH key to GitHub, it means that the SSH key you're trying to add is already associated with another GitHub account. Here are steps to resolve this issue:

Verify the Key:
Make sure the key you're trying to add is not already associated with another account. You can list your existing SSH keys on your machine:

cat ~/.ssh/id_rsa.pub
Generate a New SSH Key:
If the key is already in use, you can generate a new SSH key:

ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
Follow the prompts to save the key with a unique name (e.g., id_rsa_github).

Add the New SSH Key to the SSH Agent:
Start the SSH agent and add your new SSH key:

sh
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_rsa_github
Add the New SSH Key to Your GitHub Account:
Copy the new SSH key to your clipboard:

cat ~/.ssh/id_rsa_github.pub
Then, go to your GitHub account settings, navigate to "SSH and GPG keys," and add the new SSH key.

Update Your SSH Configuration (Optional):
If you have multiple SSH keys, you can configure SSH to use the correct key for GitHub:

nano ~/.ssh/config
Add the following configuration:

Code
Host github.com
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_rsa_github
Test Your New SSH Key:
Test the new SSH key to ensure it works correctly:

ssh -T git@github.com

If you've added your SSH key correctly but are still being prompted for a username and password when pushing to GitHub, it might be due to using the HTTPS URL for the repository instead of the SSH URL. Here's how you can switch to using SSH:

Check the Current Remote URL:

git remote -v
If you see URLs starting with https://, you need to change them to use SSH.

Change the Remote URL to Use SSH:

git remote set-url origin git@github.com:whnw/your-repo-name.git
Replace your-repo-name with the name of your repository.

Verify the Change:

git remote -v
Ensure the URLs now start with git@github.com:.

Push Your Changes:

git push origin main
