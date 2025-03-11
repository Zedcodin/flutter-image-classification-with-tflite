import 'dart:io';
import 'dart:convert'; // To work with JSON data
import 'package:flutter/material.dart';
import 'package:flutter_tflite/flutter_tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:developer' as devtools;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recipe Recognizer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  File? filePath;
  String label = '';
  bool isLoading = false;
  List<Map<String, dynamic>> recipeData = []; // List to store recipe data

  // Load the model and labels
  Future<void> _tfLiteInit() async {
    await Tflite.loadModel(
      model: "assets/model_unquant.tflite",
      labels: "assets/labels.txt",
      numThreads: 1,
      isAsset: true,
      useGpuDelegate: false,
    );

    // Load the recipe data from the JSON file
    String jsonData = await DefaultAssetBundle.of(context).loadString('assets/recipes.json');
    List<dynamic> jsonResponse = json.decode(jsonData);
    setState(() {
      recipeData = jsonResponse.map((item) => item as Map<String, dynamic>).toList();
    });
  }

  // Pick image from gallery or camera
  Future<void> pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: source);

    if (image == null) return;

    setState(() {
      filePath = File(image.path);
    });
  }

  // Classify the selected image
  Future<void> classifyImage() async {
    if (filePath == null) return;

    setState(() {
      isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    var recognitions = await Tflite.runModelOnImage(
      path: filePath!.path,
      imageMean: 0.0,
      imageStd: 224.0,
      numResults: 25,
      threshold: 0.1,
      asynch: true,
    );

    setState(() {
      isLoading = false;
    });

    // Log all model results for debugging
    devtools.log("Model Results: $recognitions");

    if (recognitions == null || recognitions.isEmpty) {
      devtools.log("No valid recognitions");
      return;
    }

    // Filter out results with confidence lower than 50% (if required)
    List<Map<String, dynamic>> filteredResults = recognitions
        .where((result) => (result['confidence'] * 100) >= 0) // Adjust as needed
        .map((result) => {
      'label': result['label'],
    })
        .toList();

    // Log filtered results
    devtools.log("Filtered Results: $filteredResults");

    // Map predictions to recipe information
    List<Map<String, dynamic>> resultWithRecipes = [];
    for (var recognition in filteredResults) {
      // Find the matching recipe from the JSON
      var matchingRecipe = recipeData.firstWhere(
            (recipe) => recipe['class_name'] == recognition['label'],
        orElse: () => {},
      );

      if (matchingRecipe.isNotEmpty) {
        resultWithRecipes.add({
          'label': recognition['label'],
          'image_url': matchingRecipe['image_url'],
          'recipe_name': matchingRecipe['Name'],
          'ingredients': matchingRecipe['Ingredients'],
          'method': matchingRecipe['Method'],
        });
      }
    }

    // Show modal with results
    showResultsModal(resultWithRecipes);
  }

  // Show a modal with prediction results
  void showResultsModal(List<Map<String, dynamic>> results) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(10), // Add some padding around the dialog
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95, // 95% width
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Adjust height based on content
            children: [
              const Text(
                "Recognition Results",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: results.map((result) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () {
                          Navigator.pop(context); // Close the modal
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RecipeDetailScreen(recipe: result),
                            ),
                          );
                        },
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            result['image_url'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          result['label'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(result['recipe_name']),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Clear the selected image
  void clearImage() {
    setState(() {
      filePath = null;
    });
  }

  // Dispose resources
  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }

  // Initialize the app
  @override
  void initState() {
    super.initState();
    _tfLiteInit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Recipe Recognizer"),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                "Welcome to Recipe Recognizer",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () => pickImage(ImageSource.gallery),
                    child: buildCard("Upload Image", "Select from gallery", Icons.upload_file),
                  ),
                  GestureDetector(
                    onTap: () => pickImage(ImageSource.camera),
                    child: buildCard("Use Camera", "Take a picture", Icons.camera_alt),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              buildImageCard(),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: filePath == null ? null : classifyImage,
                    child: isLoading ? const CircularProgressIndicator() : const Text("Confirm"),
                  ),
                  ElevatedButton(
                    onPressed: clearImage,
                    child: const Text("Cancel"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.upload_file), label: "Upload"),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: "Camera"),
        ],
        onTap: (index) {
          if (index == 0) {
            pickImage(ImageSource.gallery);
          } else if (index == 1) {
            pickImage(ImageSource.camera);
          }
        },
      ),
    );
  }

  // Build card for image source options
  Widget buildCard(String title, String description, IconData icon) {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 140,
        height: 140,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(description, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  // Build image display card
  Widget buildImageCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: double.infinity,
        height: 300,
        child: filePath == null
            ? const Icon(Icons.upload_file, size: 100, color: Colors.grey)
            : Image.file(filePath!, fit: BoxFit.cover),
      ),
    );
  }
}

// New Screen for Recipe Details
class RecipeDetailScreen extends StatelessWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top Image (35% of screen height with bottom border radius)
          Container(
            height: MediaQuery.of(context).size.height * 0.35, // 35% of screen height
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30), // Left bottom radius
                bottomRight: Radius.circular(30), // Right bottom radius
              ),
              image: DecorationImage(
                image: NetworkImage(recipe['image_url']),
                fit: BoxFit.cover,
              ),
            ),
            child: Stack(
              children: [
                // Back Button
                Positioned(
                  top: 40,
                  left: 16,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
          // Recipe Details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Label (Class Name)
                  Text(
                    recipe['label'],
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Recipe Name
                  Text(
                    recipe['recipe_name'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Ingredients
                  const Text(
                    "Ingredients",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...recipe['ingredients'].map<Widget>((ingredient) {
                    return Text(
                      "• $ingredient",
                      style: const TextStyle(fontSize: 16),
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                  // Method
                  const Text(
                    "Method",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...recipe['method'].map<Widget>((step) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        step,
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}