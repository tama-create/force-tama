/**
 * AccountServiceTest
 * AccountService のテストクラス
 * カバレッジ目標: 90% 以上
 */
@IsTest
private class AccountServiceTest {

    // ─────────────────────────────────────────
    // テストデータセットアップ
    // ─────────────────────────────────────────
    @TestSetup
    static void setupTestData() {
        List<Account> accounts = new List<Account>{
            new Account(Name = 'テスト商事', Phone = '03-1111-0001', Industry = 'Technology'),
            new Account(Name = 'テスト物産', Phone = '03-1111-0002', Industry = 'Finance'),
            new Account(Name = 'サンプル工業', Phone = '06-2222-0001', Industry = 'Manufacturing')
        };
        insert accounts;
    }

    // ─────────────────────────────────────────
    // searchByName のテスト
    // ─────────────────────────────────────────

    /**
     * 正常系: キーワードに一致するレコードが返る
     */
    @IsTest
    static void testSearchByName_hit() {
        Test.startTest();
        List<Account> results = AccountService.searchByName('テスト');
        Test.stopTest();

        System.assertEquals(2, results.size(), 'キーワード「テスト」で2件ヒットするはず');
    }

    /**
     * 正常系: 一致しないキーワードは空リストを返す
     */
    @IsTest
    static void testSearchByName_noHit() {
        Test.startTest();
        List<Account> results = AccountService.searchByName('存在しないキーワードXYZ');
        Test.stopTest();

        System.assertEquals(0, results.size(), '一致なしなら空リスト');
    }

    /**
     * 異常系: 空文字を渡すと空リストを返す
     */
    @IsTest
    static void testSearchByName_blank() {
        Test.startTest();
        List<Account> results = AccountService.searchByName('');
        Test.stopTest();

        System.assertEquals(0, results.size(), '空文字なら空リスト');
    }

    /**
     * 異常系: null を渡すと空リストを返す
     */
    @IsTest
    static void testSearchByName_null() {
        Test.startTest();
        List<Account> results = AccountService.searchByName(null);
        Test.stopTest();

        System.assertEquals(0, results.size(), 'null なら空リスト');
    }

    // ─────────────────────────────────────────
    // createAccount のテスト
    // ─────────────────────────────────────────

    /**
     * 正常系: 正しいパラメータで Account が作成される
     */
    @IsTest
    static void testCreateAccount_success() {
        Test.startTest();
        Account created = AccountService.createAccount('新規テスト株式会社', '090-9999-8888', 'Retail');
        Test.stopTest();

        System.assertNotEquals(null, created.Id, 'Id が発行されるはず');

        Account fetched = [SELECT Name, Phone, Industry FROM Account WHERE Id = :created.Id];
        System.assertEquals('新規テスト株式会社', fetched.Name, '名前が一致するはず');
        System.assertEquals('090-9999-8888', fetched.Phone, '電話番号が一致するはず');
        System.assertEquals('Retail', fetched.Industry, '業種が一致するはず');
    }

    /**
     * 異常系: 名前が空の場合は例外がスローされる
     */
    @IsTest
    static void testCreateAccount_blankName() {
        Test.startTest();
        try {
            AccountService.createAccount('', '090-0000-0000', 'Technology');
            System.assert(false, '例外がスローされるはず');
        } catch (AccountService.AccountServiceException e) {
            System.assertEquals('取引先名は必須です。', e.getMessage(), 'メッセージが一致するはず');
        }
        Test.stopTest();
    }

    /**
     * 異常系: 名前が null の場合は例外がスローされる
     */
    @IsTest
    static void testCreateAccount_nullName() {
        Test.startTest();
        try {
            AccountService.createAccount(null, null, null);
            System.assert(false, '例外がスローされるはず');
        } catch (AccountService.AccountServiceException e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
    }

    // ─────────────────────────────────────────
    // bulkUpdatePhone のテスト
    // ─────────────────────────────────────────

    /**
     * 正常系: 複数レコードの電話番号が一括更新される
     */
    @IsTest
    static void testBulkUpdatePhone_success() {
        List<Account> targets = [SELECT Id FROM Account WHERE Name LIKE 'テスト%'];
        List<Id> ids = new List<Id>();
        for (Account a : targets) {
            ids.add(a.Id);
        }

        Test.startTest();
        AccountService.bulkUpdatePhone(ids, '0120-000-999');
        Test.stopTest();

        List<Account> updated = [SELECT Phone FROM Account WHERE Id IN :ids];
        for (Account a : updated) {
            System.assertEquals('0120-000-999', a.Phone, '電話番号が更新されているはず');
        }
    }

    /**
     * 異常系: 空リストを渡しても例外が発生しない
     */
    @IsTest
    static void testBulkUpdatePhone_emptyList() {
        Test.startTest();
        AccountService.bulkUpdatePhone(new List<Id>(), '0120-000-000');
        Test.stopTest();
        // 例外なく通過すれば OK
        System.assert(true, '空リストでも例外が発生しないはず');
    }

    /**
     * 異常系: null を渡しても例外が発生しない
     */
    @IsTest
    static void testBulkUpdatePhone_null() {
        Test.startTest();
        AccountService.bulkUpdatePhone(null, '0120-000-000');
        Test.stopTest();
        System.assert(true, 'null でも例外が発生しないはず');
    }
}