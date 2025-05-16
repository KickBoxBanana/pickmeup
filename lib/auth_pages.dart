import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'main.dart';

//Handles Firebase Auth Operations
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Checks whether user has email verified, before signing in
      if (!userCredential.user!.emailVerified) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Please verify your email before signing in.',
        );
      }


      return userCredential;
    } catch (e) {
      print('Error signing in: $e');
      rethrow;
    }


  }

  // Register with email and password
  Future<UserCredential?> registerWithEmailAndPassword(
      String email, String password, String name, String username) async {
    try {
      // Create the user account
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send email verification
      await result.user!.sendEmailVerification();

      // Add user details to Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': email,
        'name': name,
        'username': username,
        'createdAt': FieldValue.serverTimestamp(),

        //Sets users' default stats
        'userLevel': 1,
        'gold': 0,
        'gems': 0,
        'health': 25,
        'maxHealth': 25,
        'mana': 30,
        'maxMana': 30,
        'xp': 0,
        'class': _firestore.collection('classes').doc('def_class'), // Default class
        'emailVerified': false, // Track verification status
      });

      //Sets default base stats
      await _firestore.collection('users').doc(result.user!.uid).collection('stats').doc('base').set({
        'intelligence':1,
        'strength':1,
        'wisdom':1,
        'vitality':1,
      });

      //Sets default battle stats
      await _firestore.collection('users').doc(result.user!.uid).collection('stats').doc('battle').set({
        'phyatk':5,
        'phydef':5,
        'magatk':5,
        'magdef':5,
      });


      return result;
    } catch (e) {
      print('Error registering user: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }
}

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  String _email = '';
  String _password = '';
  String _errorMessage = '';
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Custom Logo from assets
                  Container(
                    width: 120, // Explicitly set width
                    height: 120, // Explicitly set height
                    decoration: BoxDecoration(
                        color: theme.primaryColor,
                        shape: BoxShape.circle,
                        image: DecorationImage(
                          image: AssetImage('assets/icon/app_icon.png'),
                          fit: BoxFit.fill,
                        )
                    ),
                  ),

                  SizedBox(height: 40),

                  // App Name
                  Text(
                    'Pick-Me-Up!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),

                  SizedBox(height: 40),

                  // Error Message
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Email Field
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    onChanged: (value) => _email = value.trim(),
                  ),

                  SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        // Hiding/Showing Password
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    onChanged: (value) => _password = value,
                  ),

                  SizedBox(height: 30),

                  // Login Button
                  _isLoading
                      ? CircularProgressIndicator()
                      : SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _login,
                      child: Text(
                        'Login',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Sign Up Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => SignupPage()),
                        );
                      },
                      child: Text(
                        'Create Account',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Login validation
  void _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        await _authService.signInWithEmailAndPassword(_email, _password);
        // Navigate to home screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => NavigationPage()),
        );
      } on FirebaseAuthException catch (e) {
        print('Firebase Auth Error Code: ${e.code}');

        String message;
        switch (e.code) {
          case 'user-not-found':
            message = 'No user found with this email.';
            break;
          case 'wrong-password':
            message = 'Incorrect password.';
            break;
          case 'invalid-email':
            message = 'The email address is not valid.';
            break;
          case 'user-disabled':
            message = 'This account has been disabled.';
            break;
          case 'email-not-verified':
            message = 'Please verify your email before signing in.';
            break;
          default:
            message = 'Error (${e.code}): ${e.message}';
        }

        setState(() {
          _errorMessage = message;
        });

        // Clears the error message after 5 seconds
        Timer(Duration(seconds: 5), () {
          if (mounted) {  // Check if widget is still mounted
            setState(() {
              _errorMessage = '';
            });
          }
        });

      } catch (e) {
        print('Unexpected error type: ${e.runtimeType}');
        print('Error details: $e');

        setState(() {
          _errorMessage = 'Unexpected error: $e';
        });

        // Clear this error message too
        Timer(Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _errorMessage = '';
            });
          }
        });

      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Signup Page
class SignupPage extends StatefulWidget {
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  String _email = '';
  String _name = '';
  String _username = '';
  String _password = '';
  String _errorMessage = '';
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_add,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),

                  SizedBox(height: 30),

                  // Title
                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryColor,
                    ),
                  ),

                  SizedBox(height: 30),

                  // Error Message
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                  // Email Field
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    onChanged: (value) => _email = value.trim(),
                  ),

                  SizedBox(height: 16),

                  // Name Field
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      if (value.length < 2) {
                        return 'Name must be at least 2 characters';
                      }
                      return null;
                    },
                    onChanged: (value) => _name = value.trim(),
                  ),

                  SizedBox(height: 16),

                  // Username Field
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.alternate_email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a username';
                      }
                      if (value.length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                        return 'Username can only contain letters, numbers, and underscores';
                      }
                      return null;
                    },
                    onChanged: (value) => _username = value.trim(),
                  ),

                  SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                    onChanged: (value) => _password = value,
                  ),

                  SizedBox(height: 30),

                  // Sign Up Button
                  _isLoading
                      ? CircularProgressIndicator()
                      : SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _signup,
                      child: Text(
                        'Sign Up',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 16),

                  // Back to Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Already have an account?"),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text("Login"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _signup() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        // Check if username already exists
        QuerySnapshot usernameQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: _username)
            .get();

        if (usernameQuery.docs.isNotEmpty) {
          setState(() {
            _errorMessage = 'Username already exists. Please choose another.';
            _isLoading = false;
          });

          Timer(Duration(seconds: 5), () {
            if (mounted) {  // Check if widget is still mounted
              setState(() {
                _errorMessage = '';
              });
            }
          });

          return;
        }

        // Register the user
        await _authService.registerWithEmailAndPassword(
          _email,
          _password,
          _name,
          _username,
        );

        // Navigate back to login page instead of home page
        Navigator.pop(context);

        // Show success snackbar on the login page
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Account created successfully! Please check your email and verify before logging in.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );

      } on FirebaseAuthException catch (e) {
        // Error handling code remains the same
        print('Firebase Auth Error Code: ${e.code}');

        String message;
        switch (e.code) {
          case 'email-already-in-use':
            message = 'An account already exists with this email.';
            break;
          case 'invalid-email':
            message = 'The email address is not valid.';
            break;
          case 'weak-password':
            message = 'The password is too weak.';
            break;
          default:
            message = 'Error (${e.code}): ${e.message}';
        }
        setState(() {
          _errorMessage = message;
        });
      } on FirebaseException catch (e) {
        // Firestore error handling remains the same
        print('Firebase/Firestore Error Code: ${e.code}');
        setState(() {
          _errorMessage = 'Database error (${e.code}): ${e.message}';
        });
      } catch (e) {
        // General error handling remains the same
        print('Unexpected error type: ${e.runtimeType}');
        print('Error details: $e');
        setState(() {
          _errorMessage = 'Unexpected error: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

class EmailVerificationPage extends StatefulWidget {
  @override
  _EmailVerificationPageState createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  final AuthService _authService = AuthService();
  bool _isSendingVerification = false;
  bool _isSigningOut = false;
  bool _isCheckingVerification = false;
  String _message = '';

  @override
  void initState() {
    super.initState();
    // Check if verification has completed when page loads
    _checkVerificationStatus();
  }

  // Periodically check if user has verified their email
  Future<void> _checkVerificationStatus() async {
    setState(() {
      _isCheckingVerification = true;
      _message = '';
    });

    try {
      // Reload user to get fresh data from Firebase
      await FirebaseAuth.instance.currentUser?.reload();

      User? user = FirebaseAuth.instance.currentUser;

      if (user != null && user.emailVerified) {
        // Update Firestore record
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'emailVerified': true});

        // Show success message
        setState(() {
          _message = 'Email verified! Redirecting to login...';
        });

        // Sign out the user first
        await _authService.signOut();

        // Small delay to show success message
        Future.delayed(Duration(seconds: 2), () {
          if (mounted) {
            // Navigate to LoginPage and clear the stack
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => LoginPage()),
                  (route) => false, // This clears the navigation stack
            );
          }
        });
      } else {
        setState(() {
          _message = 'Email not verified yet. Please check your inbox.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error checking verification status: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingVerification = false;
        });
      }
    }
  }

  // Send verification email again
  Future<void> _sendVerificationEmail() async {
    setState(() {
      _isSendingVerification = true;
      _message = '';
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      await user?.sendEmailVerification();
      setState(() {
        _message = 'Verification email sent! Check your inbox.';
      });
    } catch (e) {
      setState(() {
        _message = 'Error sending verification email: $e';
      });
    } finally {
      setState(() {
        _isSendingVerification = false;
      });
    }
  }

  // Sign out
  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await _authService.signOut();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      setState(() {
        _message = 'Error signing out: $e';
        _isSigningOut = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: theme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.mark_email_read,
                    size: 80,
                    color: Colors.white,
                  ),
                ),

                SizedBox(height: 40),

                Text(
                  'Verify Your Email',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),

                SizedBox(height: 20),

                Text(
                  'We sent a verification email to:',
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 8),

                Text(
                  user?.email ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 20),

                Text(
                  'Please check your inbox and click the verification link to activate your account.',
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 30),

                // Status message
                if (_message.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _message.contains('Error')
                          ? Colors.red.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _message,
                      style: TextStyle(
                        color: _message.contains('Error')
                            ? Colors.red
                            : Colors.green,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                SizedBox(height: 30),

                // Check verification status button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCheckingVerification
                        ? null
                        : _checkVerificationStatus,
                    child: _isCheckingVerification
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text('I have Verified My Email'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Resend verification email button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: OutlinedButton(
                    onPressed: _isSendingVerification
                        ? null
                        : _sendVerificationEmail,
                    child: _isSendingVerification
                        ? CircularProgressIndicator()
                        : Text('Resend Verification Email'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.primaryColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 16),

                // Sign out button
                TextButton(
                  onPressed: _isSigningOut ? null : _signOut,
                  child: _isSigningOut
                      ? CircularProgressIndicator(strokeWidth: 2)
                      : Text('Sign Out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
