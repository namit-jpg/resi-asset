/**
 * Backs the WDDocLogo component: serves the WD_Doc_Logo static resource as a base64 data URI so Word (.doc)
 * documents show the logo without fetching it from Salesforce. Swap the static resource to change the logo.
 */
public with sharing class WDDocLogoController {
    public static final String LOGO_RESOURCE = 'WD_Doc_Logo';

    public String logoDataUri {
        get {
            if (logoDataUri == null) {
                List<StaticResource> res = [
                    SELECT Body, ContentType FROM StaticResource WHERE Name = :LOGO_RESOURCE LIMIT 1
                ];
                logoDataUri = res.isEmpty() ? '' : 'data:' + (String.isBlank(res[0].ContentType) ? 'image/png' : res[0].ContentType)
                    + ';base64,' + EncodingUtil.base64Encode(res[0].Body);
            }
            return logoDataUri;
        }
        private set;
    }
}
