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
/**
 * @author			oguzalp <oguzalp.tr@gmail.com>
 * @created			23 / 06 / 2025
 * @description	AsyncPromise provides a Promise-like interface for asynchronous Apex processing using Salesforce Queueable jobs. 
 * It supports chaining of async operations with then(), catchError(), and finally() methods similar to JavaScript Promises.
 */
public class Promisify implements Queueable, Database.AllowsCallouts {
  private List<AsyncJob> jobs;
  private List<AsyncErrorHandler> errorHandlers;
  private AsyncFinallyHandler finallyHandler;
  private AsyncContext context;
  private Integer currentJobIndex;
  private AsyncResolver resolver;
  public class AsyncException extends Exception {
  }


  /**
   * Promise States Enum
   */
  public enum PromiseState {
    PENDING, // Initial state, neither fulfilled nor rejected
    FULFILLED, // Operation completed successfully (resolved)
    REJECTED // Operation failed (rejected)
  }

  // Promise state management
  private PromiseState state;

  public Promisify() {
    //then callbacks
    this.jobs = new List<AsyncJob>();
    this.errorHandlers = new List<AsyncErrorHandler>();
    this.context = new AsyncContext();
    this.currentJobIndex = 0;
    this.state = PromiseState.PENDING;
    this.errorHandlers = new List<AsyncErrorHandler>();
    this.resolver = new AsyncResolverImpl(this.context, this);
  }

  public Promisify(Object initialData) {
    this();
    this.context.data = initialData;
  }

  /**
   * Add a job to the chain
   */
  public Promisify then(AsyncJob job) {
    this.jobs.add(job);
    return this;
  }

  /**
   * Add error handler
   */
  public Promisify catchError(AsyncErrorHandler errorHandler) {
    this.errorHandlers.add(errorHandler);
    return this;
  }

  /**
   * Add finally handler
   */
  public Promisify finall(AsyncFinallyHandler finallyHandler) {
    this.finallyHandler = finallyHandler;
    return this;
  }

  /**
   * Manually resolve the promise
   */
  public void resolve(Object value) {
    if (this.state == PromiseState.PENDING) {
      this.state = PromiseState.FULFILLED;
      this.context.data = value;

      // Execute finally if no more jobs
      if (this.finallyHandler != null) {
        this.finallyHandler.execute(value, false);
      }
    }
  }

  /**
   * Manually reject the promise
   */
  public void reject(Exception reason) {
    if (this.state == PromiseState.PENDING) {
      this.state = PromiseState.REJECTED;
      this.context.error = reason;

      // Try error handlers
      this.handleError(reason);
    }
  }

  /**
   * Check if promise is pending
   */
  public Boolean isPending() {
    return this.state == PromiseState.PENDING;
  }

  /**
   * Check if promise is fulfilled
   */
  public Boolean isFulfilled() {
    return this.state == PromiseState.FULFILLED;
  }

  /**
   * Check if promise is rejected
   */
  public Boolean isRejected() {
    return this.state == PromiseState.REJECTED;
  }

  /**
   * Get current promise state
   */
  public PromiseState getState() {
    return this.state;
  }

  /**
   * Start the async chain execution
   */
  public Promisify execute() {
    if (!jobs.isEmpty()) {
      System.enqueueJob(this);
    }
    return this;
  }

  /**
   * Queueable execute method
   */
  public void execute(QueueableContext queueableContext) {
    this.context.jobId = queueableContext.getJobId();

    if (currentJobIndex < jobs.size() && this.state == PromiseState.PENDING) {
      executeCurrentJob();
    }
  }

  /**
   * Execute current job with Promise-like resolve/reject
   */
  private void executeCurrentJob() {
    try {
      AsyncJob currentJob = jobs[currentJobIndex];
      // Execute job with resolver
      currentJob.execute(context.data, resolver);
    } catch (Exception e) {
      this.reject(e);
    }
  }

  /**
   * Continue chain execution (called by resolver)
   */
  public void continueChain() {
    currentJobIndex++;

    if (currentJobIndex < jobs.size()) {
      // Continue with next job
      System.enqueueJob(this);
    } else {
      // All jobs completed successfully
      this.resolve(context.data);
    }
  }

  /**
   * Handle error with error handlers
   */
  public void handleError(Exception error) {
    System.debug('Handling error in promise chain: ' + error.getMessage());
    if (!errorHandlers.isEmpty()) {
      try {
        // Create error resolver
        AsyncResolver errorResolver = new AsyncErrorResolver(this, error);
        // Execute first error handler
        AsyncErrorHandler handler = errorHandlers[0];
        handler.execute(error, context.data, errorResolver);
      } catch (Exception handlerError) {
        this.finalizeWithError(handlerError);
      }
    } else {
      this.finalizeWithError(error);
    }
  }

  /**
   * Finalize promise with error
   */
  private void finalizeWithError(Exception error) {
    this.state = PromiseState.REJECTED;
    this.context.error = error;

    // Execute finally block
    if (finallyHandler != null) {
      finallyHandler.execute(context.data, true);
    }
  }
  /**
   * Get current context (useful for testing)
   */
  public AsyncContext getContext() {
    return this.context;
  }

  /**
   * Static method to create new Async instance
   */
  public static Promisify create() {
    return new Promisify();
  }

  /**
   * Static method to create new Async instance with initial data
   */
  public static Promisify create(Object initialData) {
    return new Promisify(initialData);
  }

  /**
   * Static method to create resolved promise
   */
  public static Promisify resolveAsync(Object value) {
    Promisify promise = new Promisify();
    promise.resolve(value);
    return promise;
  }

  /**
   * Static method to create rejected promise
   */
  public static Promisify rejectAsync(Exception reason) {
    Promisify promise = new Promisify();
    promise.reject(reason);
    return promise;
  }

  /**
   * Interface for async job steps with Promise-like resolve/reject
   */
  public interface AsyncJob {
    void execute(Object input, AsyncResolver resolver);
  }

  /**
   * Interface for error handling
   */
  public interface AsyncErrorHandler {
    void execute(Exception error, Object input, AsyncResolver resolver);
  }

  /**
   * Interface for finally block
   */
  public interface AsyncFinallyHandler {
    void execute(Object input, Boolean hasError);
  }

  /**
   * Interface for Promise resolver (resolve/reject methods)
   */
  public interface AsyncResolver {
    void resolve(Object value);
    void reject(Exception reason);
  }

  /**
   * AsyncContext class to pass data between async operations
   */
  public class AsyncContext {
    public Object data { get; set; }
    public Exception error { get; set; }
    public Boolean hasError { get; set; }
    public String jobId { get; set; }

    public AsyncContext() {
      this.hasError = false;
    }

    public AsyncContext(Object data) {
      this();
      this.data = data;
    }
  }

  /**
   * Internal resolver implementation
   */
  public class AsyncResolverImpl implements AsyncResolver {
    private AsyncContext context;
    private Promisify asyncInstance;

    public AsyncResolverImpl(AsyncContext context, Promisify asyncInstance) {
      this.context = context;
      this.asyncInstance = asyncInstance;
    }

    public void resolve(Object value) {
      context.data = value;
      // Continue chain execution
      asyncInstance.continueChain();
    }

    public void reject(Exception reason) {
      context.error = reason;
      // Trigger error handling
      asyncInstance.handleError(reason);
    }
  }

  /**
   * Error resolver for error handling
   */
  public class AsyncErrorResolver implements AsyncResolver {
    private Promisify asyncInstance;
    private Exception originalError;

    public AsyncErrorResolver(
      Promisify asyncInstance,
      Exception originalError
    ) {
      this.asyncInstance = asyncInstance;
      this.originalError = originalError;
    }

    public void resolve(Object value) {
      // Error was handled, continue chain
      asyncInstance.context.data = value;
      asyncInstance.continueChain();
    }

    public void reject(Exception reason) {
      // Error handler failed, finalize with error
      asyncInstance.finalizeWithError(reason);
    }
  }
}
