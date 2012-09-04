/******************************************************
 *	  SAMPLE CODE FOR DREAMFORCE 2012 PRESENTATION    *
 *  "INTEGRATING PAYPAL MASS PAYMENTS WITH FORCE.COM" *
 *						   by						  *
 *				   	 SIMON LAWRENCE					  *
 *				   	 www.desynit.com				  *
 *				simon.lawrence@desynit.com			  *
 *													  *
 *	 This code is for demonstration and educational   *
 *   purposes only, and should not be used in live	  *
 *   enviroments without appropriate adaptation and   *
 *					  	knowledge					  *
 *													  *
 *   This code is distributed on an "AS IS" BASIS,	  *
 * 	 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,	  *
 *	          either express or implied.			  *
 *													  *
 ******************************************************/
 
 /*
  * This custom Apex controller is associated with the paypal_ipn.page Visualforce page. The digestMessage()
  * function is invoked automatically on page load, and processes the incoming request.
  */
public class PaypalIPNController {    
  
	/*
	 * This function examines the Parameters of the incoming request, validates them, and triggers
	 * their processing.
	 */
    public void digestMessage() {
            
        Map<String, String> parameterMap = ApexPages.currentPage().getParameters();
    
        // Rebuild the querystring. We must send it back intact to Paypal to confirm receipt.
        String queryString = generateQueryString(parameterMap);
        
        // If we can verify the queryString with Paypal, then process it.
        if (verifyQuery(queryString)) {   
            processPaymentObjects(parameterMap);
        }
    }
    
	/*
	 * This function takes the parameter map from the request URL, and iterates through it, building it back into
	 * a single, traditional UTF-8 encoded NVP string, prefixed with the PayPal notify-validate command.
	 * Returns: A string mirroring the command + URL parameters
	 */
    public String generateQueryString(Map<String, String> parameterMap) {
        
        String queryString = 'cmd=_notify-validate';
        
        for (String parameterName : parameterMap.KeySet()) {
        		queryString += '&' + parameterName + '=' + EncodingUtil.urlEncode(parameterMap.get(parameterName), 'UTF-8');
        }
        
        return queryString;
    }
    
	/*
	 * This function takes a string of parameters, builds a HTTP request to the PayPal validation service URL and
	 * dispatches it. The function looks for a response of "VERIFIED" and returns accordingly
	 * Params: A string representing a NVP list of parameters
	 * Returns: A boolean depending on whether PayPal can verify the list of parameters
	 */
    public Boolean verifyQuery(String queryString) {

        Http http = new Http();
        HttpRequest req = new HttpRequest();

        req.setEndpoint(getPaypalBaseURL());
        req.setMethod('POST');
        req.setBody(queryString);
        req.setHeader('Content-Type'  , 'application/x-www-form-urlencoded');
        req.setHeader('Content-Length', req.getBody().length().format());
        req.setTimeout(60000);
        
        system.debug('req body: ' + req.getBody());
        
        HttpResponse res = new HttpResponse();
        String verificationResponse;
        
       // If this method is being called through a test method, create a sample response
        if(Test.isRunningTest()) {
            // The sample response is based on a page parameter populated in the test method, called 'verification response'
            verificationResponse = ApexPages.currentPage().getParameters().get('verifcationResponse');
        } else {
            res = http.send(req);
            verificationResponse = res.getBody(); 
        }
        
        return verificationResponse.equalsIgnoreCase('VERIFIED');
    }
    
	/*
	 * Utility function to return a string representing the PayPal endpoint. Can be customised to load
	 * from custom settings object for better test/live seperation.
	 */
    public String getPaypalBaseURL() {
        String purl = 'sandbox.paypal.com';
        String url = 'https://www.' + purl + '/cgi-bin/webscr';
        return url;
    }
    
	/*
	 * The processPaymentObjects function takes a map of request parameters and iterates through them. It looks
	 * for any "reciever_email_n" values, and, if present, loads the status and txn_id (which is the SFID) for that 
	 * payment. A list of the payment records is then loaded, and their status' updated.
	 * Params: A map of URL request NVPs.
	 */
    public void processPaymentObjects(Map<String, String> parameterMap) {
    	
        Map <String, String> paymentStatusUpdates    = new Map <String, String>{};
        Map <String, String> paymentTransactionIdMap = new Map <String, String>{};
            
        // Now we need to go through every payment mentioned in the IPN and process it
        integer count = 1;

        // We will cycle through reciever_emails and get the Paypal_payment ID and "new" status:
        while(parameterMap.containsKey('receiver_email_'+count)) {
            paymentStatusUpdates.put(parameterMap.get('unique_id_'+count), parameterMap.get('status_'+count));
            paymentTransactionIdMap.put(parameterMap.get('unique_id_'+count), parameterMap.get('masspay_txn_id_'+count));
            count += 1;
        }
    
        List<Paypal_obj__c> paymentObjects = [SELECT Id, Paypal_status__c
                                              FROM Paypal_obj__c
                                              WHERE Id IN :paymentStatusUpdates.keySet()];
    
        // For each payment object ID in the map, set the status to the value held for this ID in the map.
		for (Paypal_obj__c payment : paymentObjects) {
			String paymentStatus = paymentStatusUpdates.get(payment.Id);
			payment.Paypal_status__c = paymentStatus;
		}

        if (!paymentObjects.isEmpty()) {
            update paymentObjects;  
        }
    }
}