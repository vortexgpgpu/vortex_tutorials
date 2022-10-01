## Vortex Tutorial - Remote Option

We suggest that you use the Open OnDemand terminal interface hosted by the CRNCH Rogues Gallery if you are not able to download and use the local VM Image. 

### Selecting a username
Please use the [spreadsheet here](https://bit.ly/3LB5HRA) to reserve a username to use for the duration of the tutorial. The organizers will share a password with you for your particular username.  

### OOD Terminal Login

1) Log into [rg-ood.crnch.gatech.edu](https://rg-ood.crnch.gatech.edu) with your GT username and password. For a tutorial, this will be provided to you along with a temporary password.
    - Select the `Vortex Tutorial` option under the `Reconfig` tab.

<div style="text-align: center;">
    
![RG OOD login](https://github.com/gt-crnch-rg/vortex_tutorials/blob/e5d2e761b635bdaa372ae5f17cc0c7adce6fb536/figs/vortex_tutorial_login.PNG "RG OOD Login")

</div>

![RG OOD Portal](https://github.com/gt-crnch-rg/vortex_tutorials/blob/e5d2e761b635bdaa372ae5f17cc0c7adce6fb536/figs/vortex_tutorial.PNG "OOD Vortex Portal")

2) Check the fields (we recommend using 2 vCPUs) and hit “Launch” to start a terminal job. 

![Vortex Job](https://github.com/gt-crnch-rg/vortex_tutorials/blob/e5d2e761b635bdaa372ae5f17cc0c7adce6fb536/figs/vortex_tutorial_2.PNG "OOD Vortex Job")

3) Wait about 30 seconds to one minute for the job to be launched on the server. When it switches to “Running”, you should be able to click `Connect` to open a remote terminal on the server.

![Vortex Running](https://github.com/gt-crnch-rg/vortex_tutorials/blob/e5d2e761b635bdaa372ae5f17cc0c7adce6fb536/figs/vortex_tutorial_3.PNG "OOD Vortex Running")

4) This new window will have a [tmux instance](https://www.ocf.berkeley.edu/~ckuehl/tmux/). Note that the escape for this particular instance is `Ctrl+A` so to create a new window you would use `Ctrl+A` and then `c`.

![Vortex Tmux](https://github.com/gt-crnch-rg/vortex_tutorials/blob/e5d2e761b635bdaa372ae5f17cc0c7adce6fb536/figs/vortex_tutorial_4.PNG "OOD Vortex Tmux")

5. When you are done you can close the web window and your scheduled job will terminate automatically. Alternatively, you can go back to your `My Interactive Sessions` tab in the Open OnDemand portal and hit `Delete` to cancel your scheduled session. Hit `Confirm` to delete the currently running job.
    * Note that your session will stay running for the length of the specified job (usually 1 hour by default).

![Vortex Delete](https://github.com/gt-crnch-rg/vortex_tutorials/blob/e5d2e761b635bdaa372ae5f17cc0c7adce6fb536/figs/vortex_tutorial_delete.PNG "OOD Vortex Delete")

### Tutorial and Environment Setup

Once you log in, your environment should already be set up. However, if you need to reinitialize your environment you can run the environment setup script.

```
$ . micro-tutorial-2022/set_vortex_env.sh
```

The tutorial repo is located under `~/micro-tutorial-2022/vortex_tutorials`. 


### Troubleshooting

1) When launching a new job, the job may fail to launch with an I/O error.
    * `Failed to submit session with the following error: sbatch: error: Batch job submission failed: I/O error writing script/environment to file.`
    * Try to relaunch the job. This may just be related to small OOD bugs.

2) When opening a VNC or Virtual Desktop session, you get the error "Failed to establish a websocket connection".
    * Clear the cache in your web browser, relogin and try to launch the job again. Specifically you may need to clear your cookies for gatech.edu domains.
