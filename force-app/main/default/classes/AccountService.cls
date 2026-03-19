/**
 * AccountService
 * Account レコードの操作をまとめたサービスクラス
 */
public with sharing class AccountService {

    /**
     * 取引先名で部分一致検索して返す
     * @param keyword 検索キーワード
     * @return 条件に一致した Account リスト
     */
    public static List<Account> searchByName(String keyword) {
        if (String.isBlank(keyword)) {
            return new List<Account>();
        }
        String likeVal = '%' + keyword + '%';
        return [
            SELECT Id, Name, Phone, Industry
            FROM Account
            WHERE Name LIKE :likeVal
            ORDER BY Name
            LIMIT 200
        ];
    }

    /**
     * 新規 Account を作成して返す
     * @param name    取引先名（必須）
     * @param phone   電話番号
     * @param industry 業種
     * @return 作成した Account
     */
    public static Account createAccount(String name, String phone, String industry) {
        if (String.isBlank(name)) {
            throw new AccountServiceException('取引先名は必須です。');
        }
        Account acc = new Account(
            Name     = name,
            Phone    = phone,
            Industry = industry
        );
        insert acc;
        return acc;
    }

    /**
     * 取引先の電話番号を一括更新する
     * @param accountIds 更新対象の Account Id リスト
     * @param newPhone   新しい電話番号
     */
    public static void bulkUpdatePhone(List<Id> accountIds, String newPhone) {
        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }
        List<Account> targets = [
            SELECT Id, Phone FROM Account WHERE Id IN :accountIds
        ];
        for (Account acc : targets) {
            acc.Phone = newPhone;
        }
        update targets;
    }

    /** カスタム例外クラス */
    public class AccountServiceException extends Exception {}
}