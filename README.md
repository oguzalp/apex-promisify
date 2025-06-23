# Async-Apex, Promise-like for Salesforce

## Overview

Promisify is an Apex Util that brings Promise-like asynchronous programming to Salesforce, enabling developers to write clean, maintainable asynchronous code using familiar Promise patterns. The library leverages Salesforce's Queueable interface to provide a robust solution for managing complex asynchronous workflows.

## Features

- **Promise-like Interface**: Familiar API similar to JavaScript Promises with `then()`, `catchError()`, and `finall()` methods
- **Method Chaining**: Chain multiple asynchronous operations in a clean, readable syntax
- **Error Handling**: Robust error handling through `catchError()` callbacks with recovery capabilities
- **Automatic Job Queueing**: Leverages Salesforce Queueable for asynchronous execution
- **Context Management**: Maintains state and data flow between async operations through AsyncContext
- **Step-by-step Execution**: Each step in the chain executes as a separate queueable job
- **Type Safety**: Type-safe implementation using Apex interfaces

## Installation

Deploy the Promisify.cls and PromisifyTest.cls files to your Salesforce org using the Salesforce CLI, Workbench, or the Salesforce Developer Console.

```bash
sf project deploy start -d force-app/main/default/classes
```

## Quick Start

### Basic Usage

```java
// Create a new promise with initial data
Promisify promise = Promisify.create('Initial Data')
    .then(new FirstAsyncJob())
    .then(new SecondAsyncJob())
    .catchError(new ErrorHandler())
    .finall(new FinallyHandler())
    .execute();
```

### Simple Example

```java
// Process accounts asynchronously
Promisify.create('Start Processing')
    .then(new QueryAccountsJob())
    .then(new UpdateAccountsJob())
    .catchError(new LogErrorJob())
    .finall(new SendNotificationJob())
    .execute();
```

## Core Concepts

### Promise States

The library uses three promise states:
- **PENDING**: Initial state, waiting to be resolved or rejected
- **FULFILLED**: Operation completed successfully
- **REJECTED**: Operation failed with an error

### AsyncContext

The `AsyncContext` class serves as the central data container and state manager for the promise chain. It includes:
- **data**: The current data being processed
- **error**: Any exception that occurred
- **state**: Current promise state (PENDING, FULFILLED, REJECTED)
- **jobId**: The current queueable job ID
- **State checking methods**: `isPending()`, `isFulfilled()`, `isRejected()`

### AsyncResolver Pattern

Each async job receives an `AsyncResolver` that provides `resolve()` and `reject()` methods, allowing jobs to control the flow:

```java
public class MyAsyncJob implements Promisify.AsyncJob {
    public void execute(Object input, Promisify.AsyncResolver resolver) {
        try {
            // Do async work
            Object result = performAsyncWork(input);
            resolver.resolve(result); // Success - continue chain
        } catch (Exception e) {
            resolver.reject(e); // Failure - trigger error handling
        }
    }
}

```
## Interface Definitions

### AsyncJob Interface

```java
public interface AsyncJob {
    void execute(Object input, AsyncResolver resolver);
}
```

**Parameters:**
- `input`: Data passed from the previous step in the chain
- `resolver`: Provides resolve() and reject() methods to control flow

### AsyncErrorHandler Interface

```java
public interface AsyncErrorHandler {
    void execute(Exception error, Object input, AsyncResolver resolver);
}
```

**Parameters:**
- `error`: The exception that occurred
- `input`: Data from the step that failed
- `resolver`: Provides resolve() and reject() methods for error recovery

### AsyncFinallyHandler Interface

```java
public interface AsyncFinallyHandler {
    void execute(Object input, Boolean hasError);
}
```

**Parameters:**
- `input`: Final data from the chain
- `hasError`: True if the chain ended with an error

### AsyncResolver Interface

```java
public interface AsyncResolver {
    void resolve(Object value);
    void reject(Exception reason);
}
```

## Usage Examples

### Basic Chain with Error Handling

```java
public void processData() {
    Promisify.create('Initial Data')
        .then(new DataValidationJob())
        .then(new DataProcessingJob())
        .then(new DataStorageJob())
        .catchError(new ErrorRecoveryJob())
        .finall(new CleanupJob())
        .execute();
}

public class DataValidationJob implements Promisify.AsyncJob {
    public void execute(Object input, Promisify.AsyncResolver resolver) {
        try {
            String data = (String) input;
            if (String.isBlank(data)) {
                resolver.reject(new AsyncException('Data cannot be empty'));
                return;
            }
            resolver.resolve('Validated: ' + data);
        } catch (Exception e) {
            resolver.reject(e);
        }
    }
}

public class ErrorRecoveryJob implements Promisify.AsyncErrorHandler {
    public void execute(Exception error, Object input, Promisify.AsyncResolver resolver) {
        System.debug('Error occurred: ' + error.getMessage());
        // Provide fallback data
        resolver.resolve('Recovery data');
    }
}
```

### Database Operations

```java
public void processAccounts(List<Id> accountIds) {
    Promisify.create(accountIds)
        .then(new QueryAccountsJob())
        .then(new UpdateAccountsJob())
        .then(new CreateContactsJob())
        .catchError(new LogErrorJob())
        .finall(new SendNotificationJob())
        .execute();
}

public class QueryAccountsJob implements Promisify.AsyncJob {
    public void execute(Object input, Promisify.AsyncResolver resolver) {
        try {
            List<Id> accountIds = (List<Id>) input;
            List<Account> accounts = [SELECT Id, Name, AnnualRevenue 
                                    FROM Account 
                                    WHERE Id IN :accountIds];
            resolver.resolve(accounts);
        } catch (Exception e) {
            resolver.reject(e);
        }
    }
}

public class UpdateAccountsJob implements Promisify.AsyncJob {
    public void execute(Object input, Promisify.AsyncResolver resolver) {
        try {
            List<Account> accounts = (List<Account>) input;
            for (Account acc : accounts) {
                acc.Description = 'Processed on ' + System.now();
            }
            update accounts;
            resolver.resolve(accounts);
        } catch (Exception e) {
            resolver.reject(e);
        }
    }
}
```

### External API Integration

```java
public void syncWithExternalSystem(String data) {
    Promisify.create(data)
        .then(new PrepareDataJob())
        .then(new CallExternalApiJob())
        .then(new ProcessResponseJob())
        .catchError(new RetryJob())
        .finall(new LogCompletionJob())
        .execute();
}

public class CallExternalApiJob implements Promisify.AsyncJob {
    public void execute(Object input, Promisify.AsyncResolver resolver) {
        try {
            String data = (String) input;
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint('https://api.example.com/process');
            request.setMethod('POST');
            request.setBody(data);
            request.setHeader('Content-Type', 'application/json');
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                resolver.resolve(response.getBody());
            } else {
                resolver.reject(new AsyncException('API Error: ' + response.getStatusCode()));
            }
        } catch (Exception e) {
            resolver.reject(e);
        }
    }
}
```

## Error Handling Patterns

### Simple Error Logging

```java
public class SimpleErrorHandler implements Promisify.AsyncErrorHandler {
    public void execute(Exception error, Object input, Promisify.AsyncResolver resolver) {
        System.debug(LoggingLevel.ERROR, 'Error in async chain: ' + error.getMessage());
        System.debug(LoggingLevel.ERROR, 'Stack trace: ' + error.getStackTraceString());
        
        // Reject to stop the chain
        resolver.reject(error);
    }
}
```

### Error Recovery

```java
public class RecoveryErrorHandler implements Promisify.AsyncErrorHandler {
    public void execute(Exception error, Object input, Promisify.AsyncResolver resolver) {
        System.debug('Attempting to recover from error: ' + error.getMessage());
        
        // Provide fallback data
        Map<String, Object> recoveryData = new Map<String, Object>{
            'originalInput' => input,
            'error' => error.getMessage(),
            'recoveryTimestamp' => System.now(),
            'status' => 'recovered'
        };
        
        resolver.resolve(recoveryData);
    }
}


```java
Promisify promise = Promisify.create('Test Data')
    .then(new TestJob())
    .execute();

// Get execution context
Promisify.AsyncContext context = promise.getContext();
System.debug('Job ID: ' + context.jobId);
System.debug('Current data: ' + context.data);
System.debug('Current state: ' + promise.getState());
System.debug('Has error: ' + context.hasError);
```

### Checking Promise State

```java
Promisify promise = Promisify.resolveAsync('Success');

System.debug('State: ' + promise.getState());
System.debug('Is pending: ' + promise.isPending());
System.debug('Is fulfilled: ' + promise.isFulfilled());
System.debug('Is rejected: ' + promise.isRejected());
```

### Using Context State Methods

```java
Promisify promise = Promisify.create('Test Data');
Promisify.AsyncContext context = promise.getContext();

// Check state using context methods
System.debug('Is pending: ' + context.isPending());
System.debug('Is fulfilled: ' + context.isFulfilled());
System.debug('Is rejected: ' + context.isRejected());
```

## Best Practices

### 1. Keep Jobs Focused
Each async job should perform a single, well-defined task:

```java
// Good: Single responsibility
public class ValidateDataJob implements Promisify.AsyncJob {
    public void execute(Object input, Promisify.AsyncResolver resolver) {
        // Only validation logic
    }
}

// Avoid: Multiple responsibilities
public class ValidateAndProcessJob implements Promisify.AsyncJob {
    public void execute(Object input, Promisify.AsyncResolver resolver) {
        // Validation + processing + database operations
    }
}
```

### 2. Proper Error Handling
Include error handlers and handle exceptions appropriately:

```java
Promisify.create(data)
    .then(new ProcessJob())
    .catchError(new ErrorHandler()) // Optional, include error handling
    .finall(new CleanupJob())       // Optional, include final job
    .execute();
```

### 3. Type Safety
Cast objects to their expected types in your job implementations:

```java
public void execute(Object input, Promisify.AsyncResolver resolver) {
    try {
        // Always cast to expected type
        List<Account> accounts = (List<Account>) input;
        // Process accounts...
    } catch (Exception e) {
        resolver.reject(e);
    }
}
```

### 4. Resource Management
Be mindful of Salesforce governor limits.

### Data Serialization
- Data passed between jobs must be serializable
- Complex objects may need to be converted to simple types
- Avoid passing non-serializable objects like Database.SaveResult

## Contributing

Contributions are welcome! Please feel free to submit a pull request or create an issue for bugs or feature requests.

## License

This library is provided under the MIT License. Feel free to use it in your Salesforce projects.

