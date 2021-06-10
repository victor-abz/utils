##nGIT Author rewrite tool

SOURCES:
https://gist.github.com/octocat/0831f3fbd83ac4d46451
https://gist.github.com/frz-dev/adf8c2c7275da1369e0cc340feda0ba0
https://gist.github.com/octocat/0831f3fbd83ac4d46451gistcomment-2178506

 use script like this > `git rewrite-author your-old-email@example.com your-name your-new-email@example.com`

 changes to ~/.gitconfig below lines
 ```
	 [alias]
	     ...
	     rewrite-author = !/<path-to-script>/git-rewrite-author.sh
```

 Note: Change the <path-to-script> with the actual path of the script

 if you need to force the change (because git usually stores the original refs under refs/original/), use `-f `to force rewrite.