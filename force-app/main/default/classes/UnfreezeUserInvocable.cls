/**
 * @description This class provides an invocable method to unfreeze a user in Salesforce by their User Id.
 * @inspiration Inspired by Salesforce freezing my only admin account in my dev org due to 'VPN stuff' even though I wasn't on a VPN.
 * @author Kevin Antonioli (braveitnow@pm.me)
 * @usage This class is intended to be used as an invocable action in Salesforce schedule triggered Flow.
 * @since 11.10.2026
 * Notes: Sucessfully tested with Integration User being set in Setup -> Process Automation Settings -> Default Workflow User.
 */
public without sharing class UnfreezeUserInvocable {
    public class Request {
        @InvocableVariable(label='Target User Id' required=true)
        public String targetUserId;
    }

    @InvocableMethod(label='Unfreeze Target User')
    public static void unfreeze(List<Request> requests) {
        Request req = requests[0];
        String status;

        try {
            List<UserLogin> userLogins = [
                SELECT Id, UserId, IsFrozen
                FROM UserLogin
                WHERE UserId = :req.targetUserId AND IsFrozen = TRUE
                WITH SYSTEM_MODE
                LIMIT 1
            ];

            if (!userLogins.isEmpty()) {
                userLogins[0].IsFrozen = false;
                Database.update(userLogins[0], AccessLevel.SYSTEM_MODE);
            }
        } catch (Exception e) {
            System.debug('ERROR: ' + e.getTypeName() + ': ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }
}
