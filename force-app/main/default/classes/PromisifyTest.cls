/**
 * MIT License
 *
 * Copyright (c) 2025 oguz.alp
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 * 
 */

@isTest
public class PromisifyTest {
  @isTest
  static void testPromiseStates() {
    Promisify promise = Promisify.create('Test');

    System.assertEquals(Promisify.PromiseState.PENDING, promise.getState());
    System.assert(promise.isPending());
    System.assert(!promise.isFulfilled());
    System.assert(!promise.isRejected());
  }

  @isTest
  static void testManualResolve() {
    Promisify promise = Promisify.resolveAsync('Success');

    System.assertEquals(Promisify.PromiseState.FULFILLED, promise.getState());
    System.assert(promise.isFulfilled());
    System.assertEquals('Success', promise.getContext().data);
  }

  @isTest
  static void testManualReject() {
    Exception testError = new AsyncException('Test Error');
    Promisify promise = Promisify.rejectAsync(testError);

    System.assertEquals(Promisify.PromiseState.REJECTED, promise.getState());
    System.assert(promise.isRejected());
    System.assertEquals(testError, promise.getContext().error);
  }

  @isTest
  static void testChainExecution() {
    Test.startTest();

    Promisify promise = Promisify.create('Test Data')
      .then(new MockJobFirst())
      .then(new MockJobSecond())
      .catchError(new ErrorHandlerJob())
      .finall(new FinallyJob())
      .execute();

    Test.stopTest();

    System.assertNotEquals(null, promise);
    System.assertNotEquals(null, promise.getContext());
  }

  @isTest
  static void testContextStateMethods() {
    Promisify promise = Promisify.create('Test Data');
    
    // Test initial state
    System.assert(promise.isPending());
    System.assert(!promise.isFulfilled());
    System.assert(!promise.isRejected());
    
    // Test fulfilled state
    promise.resolve('Success');
    System.assert(!promise.isPending());
    System.assert(promise.isFulfilled());
    System.assert(!promise.isRejected());
    
    // Test rejected state
    Promisify rejectedPromise = Promisify.create('Test Data');
    Exception testError = new AsyncException('Test Error');
    rejectedPromise.reject(testError);
    
    System.assert(!rejectedPromise.isPending());
    System.assert(!rejectedPromise.isFulfilled());
    System.assert(rejectedPromise.isRejected());
  }

  /**
   * Example job implementations with Promise-like resolve/reject
   */
  class MockJobFirst implements Promisify.AsyncJob {
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

  class MockJobSecond implements Promisify.AsyncJob {
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

  class ErrorHandlerJob implements Promisify.AsyncErrorHandler {
    public void execute(Exception error, Object input, Promisify.AsyncResolver resolver) {
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

  class FinallyJob implements Promisify.AsyncFinallyHandler {
    public void execute(Object input, Boolean hasError) {
      System.debug('Finally block executing');
      System.debug('Final data: ' + input);
      System.debug('Had error: ' + hasError);
    }
  }
}