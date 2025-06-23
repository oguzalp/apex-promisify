public with sharing class PromisifySample {
  public static void basicExample() {
    Promisify.create('Initial Data')
      .then(new Step1Job())
      .then(new Step2Job())
      .catchError(new ErrorHandlerJob())
      .finall(new FinallyJob())
      .execute();
  }

  public static void stateManagementExample() {
    Promisify promise = Promisify.create('Test Data');

    System.debug('Initial state: ' + promise.getState()); // PENDING
    System.debug('Is pending: ' + promise.isPending()); // true

    promise.then(new Step1Job())
      .then(new Step2Job())
      .then(new Step2Job())
      .catchError(new ErrorHandlerJob())
      .finall(new FinallyJob())
      .execute();
  }

  public static void manualResolveReject() {
    // Manual resolve
    Promisify resolvedPromise = Promisify.resolveAsync('Success Data');
    System.debug('Resolved state: ' + resolvedPromise.getState()); // FULFILLED

    // Manual reject
    Promisify rejectedPromise = Promisify.rejectAsync(
      new AsyncException('Failure')
    );
    System.debug('Rejected state: ' + rejectedPromise.getState()); // REJECTED
  }

  public class Step1Job implements Promisify.AsyncJob {
    public void execute(Object input, Promisify.AsyncResolver resolver) {
      try {
        System.debug('Executing Step 1 with input: ' + input);

        // Simulate async work
        List<Account> accounts = [SELECT Id, Name FROM Account LIMIT 5];

        Map<String, Object> result = new Map<String, Object>{
          'step' => 'Step1',
          'accounts' => accounts,
          'input' => input,
          'timestamp' => System.now()
        };
        // Resolve the promise
        resolver.resolve(result);
      } catch (Exception e) {
        // Reject the promise
        resolver.reject(e);
      }
    }
  }

  public class Step2Job implements Promisify.AsyncJob {
    public void execute(Object input, Promisify.AsyncResolver resolver) {
      try {
        System.debug('Executing Step 2 with input: ' + input);

        Map<String, Object> inputMap = (Map<String, Object>) input;
        List<Account> accounts = (List<Account>) inputMap.get('accounts');

        // Simulate potential failure
        if (accounts.isEmpty()) {
          resolver.reject(new AsyncException('No accounts found'));
          return;
        }

        List<Contact> contacts = [
          SELECT Id, Name, AccountId
          FROM Contact
          WHERE
            AccountId IN :new List<Id>(new Map<Id, Account>(accounts).keySet())
          LIMIT 10
        ];

        Map<String, Object> result = new Map<String, Object>{
          'step' => 'Step2',
          'accounts' => accounts,
          'contacts' => contacts,
          'previousInput' => input,
          'timestamp' => System.now()
        };

        resolver.resolve(result);
      } catch (Exception e) {
        resolver.reject(e);
      }
    }
  }

  public class ErrorHandlerJob implements Promisify.AsyncErrorHandler {
    public void execute(
      Exception error,
      Object input,
      Promisify.AsyncResolver resolver
    ) {
      try {
        System.debug('Handling error: ' + error.getMessage());

        // Decide whether to recover or fail
        if (error instanceof AsyncException) {
          // Can recover from this error
          Map<String, Object> recoveryData = new Map<String, Object>{
            'error' => error.getMessage(),
            'recoveryData' => 'Error handled successfully',
            'originalInput' => input,
            'timestamp' => System.now()
          };

          resolver.resolve(recoveryData);
        } else {
          // Cannot recover, re-throw
          resolver.reject(error);
        }
      } catch (Exception handlerError) {
        resolver.reject(handlerError);
      }
    }
  }

  public class FinallyJob implements Promisify.AsyncFinallyHandler {
    public void execute(Object input, Boolean hasError) {
      System.debug('Finally block executing');
      System.debug('Final data: ' + input);
      System.debug('Had error: ' + hasError);
    }
  }
}
