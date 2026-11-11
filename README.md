# Scheduled Admin Unfreeze for Salesforce

A small Apex action and schedule-triggered Flow that periodically unfreezes one explicitly configured Salesforce user.

Created by Kevin Antonioli.

## Why this exists

I built this after repeatedly losing access to the only administrator account in my two-seat Salesforce packaging org. The notifications referenced VPN or proxy-related activity, including occasions when I wasn't knowingly using a VPN.

The org's other licensed user needs to remain a standard user for testing. Making that account a second administrator would undermine its purpose.

This project provides a scheduled recovery mechanism: a Flow invokes Apex to clear the frozen state of a designated administrator account.

In my own org, I tested the configuration using an existing Integration User as the Default Workflow User. Following a subsequent real-world freeze, the scheduled automation ran, and I was able to reset my administrator password and regain access.

That is a report of my tested configuration, not a guarantee that the same configuration will work in every Salesforce org.

## Intended use

This project is intended for:

- Two-seat development or packaging orgs or PBO orgs where one account is the administrator and the other must remain a standard user.
- Environments where the owner knowingly accepts the trade-off of automatically unfreezing a specific account.

It is not intended for production orgs, general employee-account recovery, or environments that require security review before restoring access.

## Security considerations

This automation does not distinguish an unexpected freeze from a justified security freeze or a deliberate administrative freeze. If the configured user is frozen when the automation runs, it attempts to unfreeze that user.

Salesforce's login-anomaly containment can freeze users, revoke access and refresh tokens, and require a password reset. Automatically clearing the frozen state removes one part of that containment response without investigating the triggering activity.

The Apex implementation explicitly uses system-mode access. Treat the ability to configure or invoke this action as privileged.

Before enabling it:

- Confirm that automatic unfreezing is appropriate for this org.
- Configure only the intended recovery account.
- Restrict access to the Apex action and Flow configuration.
- Maintain MFA and review unexpected security notifications.
- Disable the Flow if you intentionally need to keep the target account frozen.

## How it works

The schedule-triggered Flow passes a configured Salesforce User ID to `UnfreezeUserInvocable`.

The Apex action:

1. Reads the first request passed to the invocable method.
2. Queries `UserLogin` for that user where `IsFrozen = true`.
3. Sets `IsFrozen` to `false`, if a matching record exists.
4. Updates the record using `AccessLevel.SYSTEM_MODE`.

If the user is not frozen, no update occurs.

Salesforce stores the frozen state on the `UserLogin` object. Setting `IsFrozen` to `false` is the underlying operation for unfreezing an account.

## Included components

| Component | Purpose |
|---|---|
| `UnfreezeUserInvocable` | Invocable Apex action that unfreezes the configured user. |
| `UnfreezeUserInvocableTest` | Tests covering freeze/unfreeze behavior and invocation. |
| `Unfreeze_User` Flow | Schedule-triggered Flow that runs the action daily for the configured target user. |
| `Unfreeze_User` permission set | Grants access to the `UnfreezeUserInvocable` Apex class. |

The supplied Flow metadata specifies API version `66.0`.

The permission set grants Apex class access only. It does not grant additional user-management permissions.

## Setup

### 1. Deploy the components

Deploy:

- The Apex class and its class metadata.
- The Apex test class and its class metadata.
- The `Unfreeze_User` permission set.
- The schedule-triggered Flow.

### 2. Post deployment steps
- Replace the Flow's `TARGET_USER_ID` constant with the User ID of the administrator account you intend to recover.
- Change the Flow status from `Active` to `Draft` for initial deployment.
- Replace the exported schedule with your desired start date and daily execution time.

Example using the Salesforce CLI:

```bash
sf project deploy start --source-dir force-app --target-org <your-org-alias> --test-level RunSpecifiedTests --tests UnfreezeUserInvocableTest
```

### 3. Configure the execution user

In the author's tested configuration:

1. The existing regular Integration User (that is in virtually every org) was selected as the Default Workflow User.
2. The `Unfreeze_User` permission set was assigned to that user.

To set the Default Workflow User, navigate to:

**Setup → Process Automation Settings → Default Workflow User**

Select the intended user and save.

"Integration User" refers to the specific existing account used in the author's org. It is not a guarantee that every account with that name, profile, or an integration-oriented license will behave identically. Validate the actual scheduled execution in your own org rather than relying only on the account's display name.

### 4. Configure and activate the Flow

Open the Flow in Flow Builder and confirm:

- `TARGET_USER_ID` identifies the intended administrator.
- The Apex action is `Unfreeze Target User`.
- The action's `targetUserId` input references `TARGET_USER_ID`.
- The daily schedule has the intended start date and time.
- The Flow is activated only after configuration and testing are complete.

### 5. Validate recovery safely

Do not begin by freezing your only usable administrator account.

First, use a noncritical test user and retain working administrator access:

1. Configure the target as the test user.
2. Freeze that user.
3. Let the scheduled Flow execute.
4. Confirm that the target user is no longer frozen.
5. Restore the target constant to the intended administrator.
6. Save and activate the final configuration.

The supplied tests exercise the Apex under `System.runAs`; they do not, by themselves, demonstrate that the deployed scheduled Flow will execute successfully in your org.

## What recovery looks like

If the action successfully clears the frozen state, you may still need to reset your password or reauthenticate connected applications.

Salesforce's anomaly-containment response can revoke existing tokens and require a password reset in addition to freezing the account. This utility changes only the frozen state.

It does not:

- Reset passwords.
- Restore revoked tokens or sessions.
- Reactivate inactive users.
- Diagnose the event that triggered a freeze.
- Prevent a future freeze.
- Unlock accounts locked because of repeated incorrect password attempts (a separate recovery operation).

## Current implementation limitations

### One request is processed

Although the invocable method accepts a list, it processes only `requests[0]`. The supplied Flow is configured for one target user. Do not treat the current class as a bulk-capable action.

### Errors are written to debug output only

Exceptions inside the `try` block are caught and written using `System.debug`. The action does not return a success/failure result and does not rethrow exceptions. A completed Flow interview is not proof that an unfreeze succeeded.

### Input validation is limited

The method accesses `requests[0]` before entering the `try` block. Null or empty request lists are not handled, and the target User ID is not explicitly validated.

### The action does not enforce a target allowlist

The target account is selected by Flow configuration. The Apex class itself does not restrict requests to a particular administrator or org type. The Developer Edition/two-seat restriction is an intended-use policy, not a restriction enforced in code.

### Tests depend on org configuration

The test class queries for:

- A profile named `Standard User`.
- An active user whose profile is `Analytics Cloud Integration User` or whose name is `Integration User`.

Review these assumptions before deploying to another org.

### Recovery is scheduled, not immediate

The supplied Flow runs daily. A freeze remains in place until a successful execution or another recovery action.

## Support and status

This is a community utility based on the author's own tested configuration. It is not a Salesforce-endorsed recovery mechanism, and compatibility with every org, user license, or future platform release has not been established. Use at your own risk.
