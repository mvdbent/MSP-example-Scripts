# MSP-example-Scripts

_**Current state of the scripts are:** "the scripts are examples how you can do this"_

```THE SCRIPTS ARE PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY 
AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
I BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, 
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF 
THE POSSIBILITY OF SUCH DAMAGE.
```

![GitHub](https://img.shields.io/github/license/mvdbent/MSP-example-Scripts)

Here some examples script for Managed Service Providers (MSP) how to automate some task.
There will certainly be better workflows, but the purpose of these scripts is to give you an idea, of course you are free to adapt them to your situation.
 
---

> I try to prevent passwords or API hashes in scripts, to prevent this I use the keychain for this. **Keep in mind that this is only if the passwords or API hashes are stored in the keychain on the machine where the script is being run.** 

## Securely store Passwords into the macOS Keychain

Why put cleartext passwords in scripts, when we can use the macOS Keychain to securely store this information for us.

I added this easy way to the script, so we can have a placeholder for the password rather then leaking this password within the script.

**How to**

After creating the API user with the API Debugger tool, we received the Hue API Hash. 
We are going to add the Hue API Hash into the macOS Keychain with the `security` command.
For this command we are using `-T` to add an entry to the login keychain and add the `security` binary to "Always allow access by these applications:" list in the Access Control preferences.

```bash
security add-generic-password [-s service] [-a account] [-w password] -T [appPath]

Usage: 
-s service      Specify service name (required)
-a account      Specify account name (required)
-w password     Specify password to be added. Put at end of command to be prompted (recommended)
-T appPath      Specify an application which may access this item (multiple -T options are allowed)
```

**Example:**
```bash
security add-generic-password -s hueAPIHash -a HUEAPI -w FIAqb-53KaLBVzXKscihomProgvhUkRko59TAuV -T /usr/bin/security
```

Now we securely store the Hue API Hash into the macOS Keychain, and allowing the `security` binary to access this entry. 
We can use the `security` command to fetch the Hue API Hash.

```bash
security find-generic-password [-s service] -w 
Usage:
-s service      Match service string
-w              Display the password(only) for the item found
```

We only need to provide the service name and ask for the password

**Example:**
```bash
security find-generic-password -s "hueAPIHash" -w
#RESULT
FIAqb-53KaLBVzXKscihomProgvhUkRko59TAuV
```

See the man page security in terminal for more options. `man security`