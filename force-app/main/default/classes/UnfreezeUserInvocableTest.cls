@IsTest
public class UnfreezeUserInvocableTest {
    @IsTest
    static void integrationUserUserLoginAccess() {
        User integrationUser = [
            SELECT Id, Username
            FROM User
            WHERE (Profile.Name = 'Analytics Cloud Integration User' OR Name = 'Integration User') AND IsActive = TRUE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        Boolean objReadable;
        Boolean objUpdateable;
        Boolean fieldReadable;
        Boolean fieldUpdateable;

        System.runAs(integrationUser) {
            Schema.DescribeSObjectResult d = UserLogin.SObjectType.getDescribe();
            objReadable = d.isAccessible();
            objUpdateable = d.isUpdateable();

            Schema.DescribeFieldResult f = UserLogin.IsFrozen.getDescribe();
            fieldReadable = f.isAccessible();
            fieldUpdateable = f.isUpdateable();
        }
    }

    @IsTest
    static void integrationUserCanFreezeAndUnfreeze() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniq = String.valueOf(System.currentTimeMillis());
        User target = new User(
            Alias = 'frztest',
            Email = 'frztest' + uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'FreezeTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Denver',
            ProfileId = p.Id,
            Username = 'frztest' + uniq + '@example.com'
        );
        insert target;

        User integrationUser = [
            SELECT Id, Username
            FROM User
            WHERE (Profile.Name = 'Analytics Cloud Integration User' OR Name = 'Integration User') AND IsActive = TRUE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        Boolean frozenAfterFreeze;
        Boolean frozenAfterUnfreeze;

        System.runAs(integrationUser) {
            UserLogin ul = [
                SELECT Id, IsFrozen
                FROM UserLogin
                WHERE UserId = :target.Id
                LIMIT 1
            ];

            ul.IsFrozen = true;
            Database.update(ul, AccessLevel.SYSTEM_MODE);
            frozenAfterFreeze = [SELECT IsFrozen FROM UserLogin WHERE UserId = :target.Id LIMIT 1].IsFrozen;

            ul.IsFrozen = false;
            Database.update(ul, AccessLevel.SYSTEM_MODE);
            frozenAfterUnfreeze = [SELECT IsFrozen FROM UserLogin WHERE UserId = :target.Id LIMIT 1].IsFrozen;
        }

        Assert.isTrue(frozenAfterFreeze, 'Freeze did not stick');
        Assert.isFalse(frozenAfterUnfreeze, 'Unfreeze did not stick');
    }

    @IsTest
    static void integrationUserRunsRealInvocable() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniq = String.valueOf(System.currentTimeMillis());
        User target = new User(
            Alias = 'invtest',
            Email = 'invtest' + uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'InvocableTest',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            TimeZoneSidKey = 'America/Denver',
            ProfileId = p.Id,
            Username = 'invtest' + uniq + '@example.com'
        );
        insert target;

        User integrationUser = [
            SELECT Id, Username
            FROM User
            WHERE (Profile.Name = 'Analytics Cloud Integration User' OR Name = 'Integration User') AND IsActive = TRUE
            ORDER BY CreatedDate ASC
            LIMIT 1
        ];

        Boolean frozenBefore;
        Boolean frozenAfter;

        System.runAs(integrationUser) {
            UserLogin ul = [SELECT Id, IsFrozen FROM UserLogin WHERE UserId = :target.Id LIMIT 1];
            ul.IsFrozen = true;
            Database.update(ul, AccessLevel.SYSTEM_MODE);
            frozenBefore = [SELECT IsFrozen FROM UserLogin WHERE UserId = :target.Id LIMIT 1].IsFrozen;

            UnfreezeUserInvocable.Request req = new UnfreezeUserInvocable.Request();
            req.targetUserId = target.Id;

            Test.startTest();
            UnfreezeUserInvocable.unfreeze(new List<UnfreezeUserInvocable.Request>{ req });
            Test.stopTest();

            frozenAfter = [SELECT IsFrozen FROM UserLogin WHERE UserId = :target.Id LIMIT 1].IsFrozen;
        }
        Assert.isTrue(frozenBefore, 'Setup freeze did not stick');
        Assert.isFalse(frozenAfter, 'Invocable did not unfreeze the user');
    }

    private static User createUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniq = String.valueOf(Crypto.getRandomInteger()).replace('-', 'n');
        User u = new User(
            Alias = 'unf' + uniq.left(4),
            Email = 'unfreeze' + uniq + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Unfreeze',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Denver',
            Username = 'unfreeze' + uniq + '@example.com.test'
        );
        insert u;
        return u;
    }

    private static UnfreezeUserInvocable.Request buildRequest(Id userId) {
        UnfreezeUserInvocable.Request req = new UnfreezeUserInvocable.Request();
        req.targetUserId = userId;
        return req;
    }

    @IsTest
    static void unfreezesFrozenUser() {
        User u = createUser();
        Account a = new Account(Name = 'Status');
        insert a;

        System.runAs(new User(Id = UserInfo.getUserId())) {
            UserLogin ul = [SELECT Id, IsFrozen FROM UserLogin WHERE UserId = :u.Id LIMIT 1];
            ul.IsFrozen = true;
            update ul;

            Test.startTest();
            UnfreezeUserInvocable.unfreeze(new List<UnfreezeUserInvocable.Request>{ buildRequest(u.Id) });
            Test.stopTest();

            Assert.isFalse([SELECT IsFrozen FROM UserLogin WHERE UserId = :u.Id].IsFrozen);
        }
    }
}
