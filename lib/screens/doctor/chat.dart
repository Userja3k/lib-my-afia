import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart' as ap;
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:http/http.dart' as http;
import 'package:hospital_virtuel/screens/patient/dossier_medical_markdown.dart';
import 'package:hospital_virtuel/screens/patient/full_screen_image_page.dart';
import 'package:hospital_virtuel/screens/doctor/ordonance.dart';
import 'package:hospital_virtuel/screens/doctor/rappel_medicament.dart';

class ChatPage extends StatefulWidget {
  final String contactId;
  final String contactName;

  const ChatPage({
    super.key,
    required this.contactId,
    required this.contactName,
  });

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, bool> _isTimestampVisible = {};
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isDoctor = false;

  // Pour la lecture des messages audio
  final ap.FlutterSoundPlayer _audioPlayer = ap.FlutterSoundPlayer();
  bool _isAudioPlaying = false;
  String? _currentlyPlayingAudioUrl;
  String? _currentlyPlayingAudioUrlForProgress;
  Duration? _audioDuration;
  Duration? _audioPosition;
  bool _isRecording = false;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _checkIfDoctor();
    
    _recorder.openRecorder().then((value) {
      // Recorder is ready
    });

    _audioPlayer.openPlayer().then((value) {
      // Player is ready
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _recorder.closeRecorder();
    _audioPlayer.closePlayer();
    super.dispose();
  }

  Future<void> _checkIfDoctor() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final doctorDoc = await FirebaseFirestore.instance
          .collection('doctors')
          .doc(currentUser.uid)
          .get();
      if (mounted) {
        setState(() {
          _isDoctor = doctorDoc.exists;
        });
      }
    }
  }

  String _getChatRoomId(String userId1, String userId2) {
    if (userId1.hashCode <= userId2.hashCode) {
      return '${userId1}_$userId2';
    } else {
      return '${userId2}_$userId1';
    }
  }

    Future<void> _uploadAndSendFile(XFile file, String messageType, {String? textCaption}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final chatRoomId = _getChatRoomId(currentUser.uid, widget.contactId);
    final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';

    final Reference storageRef = FirebaseStorage.instance
        .ref('chat_attachments/$chatRoomId/$messageType/$uniqueFileName');

    try {
      setState(() {
        // Optionnel: afficher un indicateur de chargement
      });
      UploadTask uploadTask;
      if (kIsWeb) {
        uploadTask = storageRef.putData(await file.readAsBytes(), SettableMetadata(contentType: file.mimeType));
      } else {
        uploadTask = storageRef.putFile(File(file.path));
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('messages').add({
        'senderId': currentUser.uid,
        'messageType': messageType,
        'receiverId': widget.contactId,
        'fileUrl': downloadUrl,
        'fileName': file.name,
        'message': messageType == 'audio' ? '' : (textCaption ?? ''),
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'envoi du fichier: $e')),
        );
      }
    } finally {
       setState(() {
        // Optionnel: cacher l'indicateur de chargement
       });
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      String? caption = await _showCaptionDialog();
      await _uploadAndSendFile(image, 'image', textCaption: caption);
    }
  }

  Future<void> _pickDocument() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null) {
      XFile xFileFromResult;
      PlatformFile platformFile = result.files.single;
      if (kIsWeb) {
          if (platformFile.bytes == null) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de lire le fichier web.')));
              return;
          }
          String? mimeType;
          if (platformFile.extension != null) {
              if (platformFile.extension!.toLowerCase() == 'pdf') {
                mimeType = 'application/pdf';
              } else if (['jpg', 'jpeg'].contains(platformFile.extension!.toLowerCase())) mimeType = 'image/jpeg';
              else if (platformFile.extension!.toLowerCase() == 'png') mimeType = 'image/png';
              else if (['doc', 'docx'].contains(platformFile.extension!.toLowerCase())) mimeType = 'application/msword';
              else if (['xls', 'xlsx'].contains(platformFile.extension!.toLowerCase())) mimeType = 'application/vnd.ms-excel';
          }
          xFileFromResult = XFile.fromData(platformFile.bytes!, name: platformFile.name, mimeType: mimeType, length: platformFile.size);
      } else {
          if (platformFile.path == null) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chemin du fichier non disponible.')));
              return;
          }
          xFileFromResult = XFile(platformFile.path!);
      }
      String? caption = await _showCaptionDialog();
      await _uploadAndSendFile(xFileFromResult, 'document', textCaption: caption);
    }
  }

  Future<void> _takePhoto() async {
    final ImagePicker picker = ImagePicker();
    ImageSource source;

    if (kIsWeb) {
      source = ImageSource.gallery;
    } else {
      source = (Platform.isAndroid || Platform.isIOS) ? ImageSource.camera : ImageSource.gallery;
    }

    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      String? caption = await _showCaptionDialog();
      await _uploadAndSendFile(image, 'image', textCaption: caption);
    }
  }

  void _sendMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      final message = _controller.text.trim();
      
      if (_recordingPath != null) {
        try {
          print('Sending audio message, path: $_recordingPath');
          
          if (kIsWeb) {
            await _sendWebAudioMessage();
          } else {
            XFile audioFile = XFile(_recordingPath!, name: "voice_message_${DateTime.now().millisecondsSinceEpoch}.aac");
            await _uploadAndSendFile(audioFile, 'audio');
          }
          
          setState(() {
            _recordingPath = null;
            _isAudioPlaying = false;
            _currentlyPlayingAudioUrl = null;
            _audioPosition = Duration.zero;
            _audioDuration = null;
          });
          _scrollToBottom();
        } catch (e) {
          print('Error sending audio message: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur lors de l\'envoi du message vocal: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      return;
    }
      
      if (message.isNotEmpty) {
        await FirebaseFirestore.instance.collection('messages').add({
          'senderId': currentUser.uid,
          'messageType': 'text',
          'receiverId': widget.contactId,
          'message': message,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
        _controller.clear();
        _scrollToBottom();
      }
    }
  }

  Future<void> _toggleRecording() async {
    if (!kIsWeb && !await Permission.microphone.request().isGranted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission microphone refusée')));
      return;
    }

    if (_recorder.isRecording) {
      final path = await _recorder.stopRecorder();
      print('Recording stopped, path: $path');
      setState(() {
        _isRecording = false;
        _recordingPath = path;
      });
    } else {
      try {
        if (kIsWeb) {
          await _recorder.startRecorder(codec: Codec.opusWebM);
        } else {
          Directory? tempDir = await getTemporaryDirectory();
          String filePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
          await _recorder.startRecorder(toFile: filePath, codec: Codec.aacADTS);
        }

        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        print('Error starting recorder: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur enregistrement: $e')),
          );
        }
      }
    }
  }

  Future<void> _sendWebAudioMessage() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _recordingPath == null) return;

    try {
      final chatRoomId = _getChatRoomId(currentUser.uid, widget.contactId);
      final uniqueFileName = 'voice_message_${DateTime.now().millisecondsSinceEpoch}.webm';

      final Reference storageRef = FirebaseStorage.instance
          .ref('chat_attachments/$chatRoomId/audio/$uniqueFileName');

      final response = await http.get(Uri.parse(_recordingPath!));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        final UploadTask uploadTask = storageRef.putData(
          bytes, 
          SettableMetadata(contentType: 'audio/webm')
        );

        final TaskSnapshot snapshot = await uploadTask;
        final String downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance.collection('messages').add({
          'senderId': currentUser.uid,
          'messageType': 'audio',
          'receiverId': widget.contactId,
          'fileUrl': downloadUrl,
          'fileName': uniqueFileName,
          'message': '',
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
        });
      } else {
        throw Exception('Impossible de récupérer les données audio');
      }
    } catch (e) {
      print('Error in _sendWebAudioMessage: $e');
      rethrow;
    }
  }

  void _deleteRecording() {
    setState(() {
      _recordingPath = null;
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<List<Map<String, String>>> _fetchOrdonnances(
      String patientId, {String? prescribingDoctorId}) async {
    List<Map<String, String>> ordonnances = [];
    try {
      Query query = FirebaseFirestore.instance
          .collection('ordonnances_metadata')
          .where('patientId', isEqualTo: patientId)
          .orderBy('timestamp', descending: true);

      if (prescribingDoctorId != null) {
        query = query.where('doctorId', isEqualTo: prescribingDoctorId);
      }

      final querySnapshot = await query.get();

      for (var doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null && data['fileName'] != null && data['downloadUrl'] != null) {
          ordonnances.add({'name': data['fileName'], 'url': data['downloadUrl']});
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération des ordonnances depuis Firestore: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de récupération des ordonnances: $e')),
        );
      }
    }
    return ordonnances;
  }

  void _showOrdonnancesDialog(String targetPatientId, String dialogTitleName) async {
    List<Map<String, String>> ordonnances;
    if (_isDoctor) {
      ordonnances = await _fetchOrdonnances(targetPatientId, prescribingDoctorId: FirebaseAuth.instance.currentUser!.uid);
    } else {
      ordonnances = await _fetchOrdonnances(targetPatientId);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        String title;
        if (_isDoctor) {
          title = 'Ordonnances pour $dialogTitleName';
        } else {
          title = 'Mes Ordonnances';
        }
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: ordonnances.isEmpty
                ? Text('Aucune ordonnance trouvée.')
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: ordonnances.length,
                    itemBuilder: (context, index) {
                      final ordonnance = ordonnances[index];
                      return ListTile(
                        leading: Icon(Icons.description_outlined, color: Theme.of(context).primaryColor),
                        title: Text(ordonnance['name']!),
                        onTap: () async {
                          if (await canLaunchUrl(Uri.parse(ordonnance['url']!))) {
                            await launchUrl(Uri.parse(ordonnance['url']!));
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d\'ouvrir le fichier.')));
                          }
                        },
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Fermer'))],
        );
      },
    );
  }

  Future<String?> _showCaptionDialog() async {
    TextEditingController captionController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter une légende (optionnel)'),
        content: TextField(
          controller: captionController,
          decoration: const InputDecoration(hintText: "Légende..."),
          autofocus: true,
        ),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context, captionController.text.trim()),
          ),
        ],
      ),
    );
  }

  Future<void> _playAudio(String audioUrl, String messageId) async {
    try {
      if (_isAudioPlaying && _currentlyPlayingAudioUrl == audioUrl) {
        await _audioPlayer.pausePlayer();
        setState(() {
          _isAudioPlaying = false;
        });
      } else {
        if (_isAudioPlaying && _currentlyPlayingAudioUrl != audioUrl) {
          await _audioPlayer.stopPlayer();
        }
        
        setState(() {
          _audioDuration = null;
          _audioPosition = Duration.zero;
          _currentlyPlayingAudioUrl = audioUrl;
        });
        
        await _audioPlayer.startPlayer(
          fromURI: audioUrl,
          whenFinished: () {
            if (mounted) {
              setState(() {
                _isAudioPlaying = false;
                _currentlyPlayingAudioUrl = null;
                _audioPosition = Duration.zero;
                _audioDuration = null;
              });
            }
          },
        );
        
        setState(() {
          _isAudioPlaying = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la lecture: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _deleteAudioMessage(String messageId) async {
    try {
      bool? shouldDelete = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Confirmer la suppression'),
            content: const Text('Êtes-vous sûr de vouloir supprimer ce message vocal ? Cette action est irréversible.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Supprimer'),
              ),
            ],
          );
        },
      );

      if (shouldDelete == true) {
        if (_currentlyPlayingAudioUrl != null && _isAudioPlaying) {
          await _audioPlayer.stopPlayer();
          setState(() {
            _isAudioPlaying = false;
            _currentlyPlayingAudioUrl = null;
            _audioPosition = null;
            _audioDuration = null;
          });
        }

        await FirebaseFirestore.instance
            .collection('messages')
            .doc(messageId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Message vocal supprimé avec succès'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 800;

      Widget chatScaffold = Scaffold(
        backgroundColor: isDesktop
            ? Theme.of(context).canvasColor
            : Theme.of(context).colorScheme.surface.withOpacity(0.95),
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          title: Text(
            '  ${widget.contactName}',
            style: GoogleFonts.lato(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          centerTitle: false,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade800, Colors.lightBlue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: isDesktop ? 0 : 3.0,
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (widget.contactName == 'MyAFYA AI')
              IconButton(
                icon: const Icon(Icons.call, color: Colors.white),
                tooltip: 'Appeler',
                onPressed: () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Appel MyAFYA AI bientôt disponible')),
                    );
                  }
                },
              )
            else if (!_isDoctor && FirebaseAuth.instance.currentUser != null)
              IconButton(
                icon: Icon(Icons.folder_open_outlined),
                tooltip: 'Mes ordonnances',
                onPressed: () => _showOrdonnancesDialog(
                    FirebaseAuth.instance.currentUser!.uid, "Moi-même"),
              ),
            if (_isDoctor && widget.contactName != 'MyAFYA AI')
              PopupMenuButton<int>(
                onSelected: (int value) {
                  if (value == 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const OrdonnanceScreen(),
                        settings: RouteSettings(arguments: widget.contactId),
                      ),
                    );
                  } else if (value == 2) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DossierMedicalMarkdownPage(
                          patientId: widget.contactId,
                          patientName: widget.contactName,
                        ),
                      ),
                    );
                  } else if (value == 3) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RappelMedicamentPage(
                          patientId: widget.contactId,
                          patientName: widget.contactName,
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    PopupMenuItem<int>(
                      value: 1,
                      child: Row(
                        children: [
                          Icon(Icons.receipt, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Produire une ordonnance'),
                        ],
                      ),
                    ),
                    PopupMenuItem<int>(
                      value: 2,
                      child: Row(
                        children: [
                          Icon(Icons.folder_open, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Voir le dossier du patient'),
                        ],
                      ),
                    ),
                    PopupMenuItem<int>(
                      value: 3,
                      child: Row(
                        children: [
                          Icon(Icons.medication, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Rappel de médicament'),
                        ],
                      ),
        ),
                  ];
                },
              ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('messages')
                    .where('senderId',
                        isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .where('receiverId', isEqualTo: widget.contactId)
                    .orderBy('timestamp', descending: false)
                    .snapshots(),
                builder: (context, sentSnapshot) {
                  if (sentSnapshot.hasError) {
                    return Center(child: Text('Erreur: ${sentSnapshot.error}'));
                  }
                  if (sentSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  var sentMessages = sentSnapshot.data?.docs ?? [];

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('messages')
                        .where('senderId', isEqualTo: widget.contactId)
                        .where('receiverId',
                            isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                        .orderBy('timestamp', descending: false)
                        .snapshots(),
                    builder: (context, receivedSnapshot) {
                      if (receivedSnapshot.hasError) {
                        return Center(
                            child: Text('Erreur: ${receivedSnapshot.error}'));
                      }
                      if (receivedSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      var receivedMessages =
                          receivedSnapshot.data?.docs ?? [];
                      var allMessages = [...sentMessages, ...receivedMessages];
                      
                      // Filtrer les messages supprimés pour l'utilisateur actuel
                      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
                      allMessages = allMessages.where((message) {
                        final data = message.data() as Map<String, dynamic>;
                        final deletedFor = data['deletedFor'] as List<dynamic>?;
                        return deletedFor == null || !deletedFor.contains(currentUserId);
                      }).toList();
                      
                      allMessages.sort((a, b) {
                        var aTimestamp = a['timestamp'] as Timestamp?;
                        var bTimestamp = b['timestamp'] as Timestamp?;
                        if (aTimestamp == null && bTimestamp == null) return 0;
                        if (aTimestamp == null) return -1;
                        if (bTimestamp == null) return 1;
                        return aTimestamp.compareTo(bTimestamp);
                      });

                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _scrollToBottom());

                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        itemCount: allMessages.length,
                        itemBuilder: (context, index) {
                          var data =
                              allMessages[index].data() as Map<String, dynamic>;
                          bool isMe = data['senderId'] ==
                              FirebaseAuth.instance.currentUser?.uid;
                          String messageId = allMessages[index].id;
                          Timestamp? timestamp =
                              data['timestamp'] as Timestamp?;
                          String formattedTime = timestamp != null
                              ? DateFormat('dd/MM/yyyy HH:mm')
                                  .format(timestamp.toDate())
                              : 'Envoi...';
                          String messageType = data['messageType'] ?? 'text';
                          String? fileUrl = data['fileUrl'];
                          String? fileName = data['fileName'];
                          String messageText = data['message'] ?? '';
                          bool isRead = data['isRead'] ?? false;
                          bool isEdited = data['isEdited'] ?? false;
                          String? messageTypeSpecial = data['type'];
                          String? address = data['address'];
                          bool isCurrentLocation = data['isCurrentLocation'] ?? false;

                          bool isConfirmation =
                              messageText.toLowerCase().contains("confirmé");
                          bool isFailure =
                              messageText.toLowerCase().contains("échec");
                          bool isSpecialMessage = isConfirmation || isFailure;

                          if (!isMe && !isRead) {
                            FirebaseFirestore.instance
                                .collection('messages')
                                .doc(messageId)
                                .update({'isRead': true});
                          }

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _isTimestampVisible[messageId] =
                                    !(_isTimestampVisible[messageId] ?? false);
                              });
                            },
                            onLongPress: isMe && _canEditOrDeleteMessage(timestamp) 
                                ? () => _showMessageActions(messageId, messageText, messageType)
                                : null,
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 4.0, horizontal: 10.0),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 8.0),
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.of(context).size.width *
                                              0.75),
                                  decoration: BoxDecoration(
                                    color: isSpecialMessage
                                        ? (isConfirmation
                                            ? Colors.green[100]
                                            : Colors.red[100])
                                        : (isMe ? Colors.blue : Colors.white),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(18),
                                      topRight: Radius.circular(18),
                                      bottomLeft: isMe
                                          ? Radius.circular(18)
                                          : Radius.circular(4),
                                      bottomRight: isMe
                                          ? Radius.circular(4)
                                          : Radius.circular(18),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 3,
                                        offset: Offset(1, 1),
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (messageType == 'image' &&
                                          fileUrl != null)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4.0),
                                          child: GestureDetector(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      FullScreenImagePage(
                                                    imageProvider:
                                                        NetworkImage(fileUrl),
                                                    tag: fileUrl,
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Hero(
                                              tag: fileUrl,
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: Image.network(fileUrl,
                                                    height: 150,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context,
                                                            error,
                                                            stackTrace) =>
                                                        SizedBox(
                                                            height: 150,
                                                            child: Center(
                                                                child: Icon(
                                                                    Icons
                                                                        .broken_image,
                                                                    color: isMe
                                                                        ? Colors
                                                                            .white70
                                                                        : Colors
                                                                            .black54,
                                                                    size:
                                                                        50))),
                                                    loadingBuilder: (context,
                                                        child,
                                                        loadingProgress) {
                                                  if (loadingProgress == null)
                                                    return child;
                                                  return SizedBox(
                                                      height: 150,
                                                      child: Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                        value: loadingProgress
                                                                    .expectedTotalBytes !=
                                                                null
                                                            ? loadingProgress
                                                                    .cumulativeBytesLoaded /
                                                                loadingProgress
                                                                    .expectedTotalBytes!
                                                            : null,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                                    Color>(
                                                                isMe
                                                                    ? Colors
                                                                        .white
                                                                    : Colors
                                                                        .blue),
                                                      )));
                                                }),
                                              ),
                                            ),
                                          ),
                                        )
                                      else if (messageType == 'audio' &&
                                          fileUrl != null)
                                        _buildAudioPlayerWidget(fileUrl,
                                            fileName ?? 'Audio', messageId, isMe)
                                      else if (messageType == 'document' &&
                                          fileUrl != null)
                                        _buildDocumentWidget(
                                            fileUrl,
                                            fileName ?? 'Document',
                                            isMe)
                                      else if (messageTypeSpecial == 'appointment_info')
                                        _buildAppointmentInfoCard(messageText, isMe, address, isCurrentLocation, messageTypeSpecial)
                                      else
                                        Text(
                                          messageText,
                                          style: TextStyle(
                                            color: isSpecialMessage
                                                ? (isConfirmation
                                                    ? Colors.green[800]
                                                    : Colors.red[800])
                                                : (isMe
                                                    ? Colors.white
                                                    : Colors.black87),
                                            fontSize: 16,
                                          ),
                                        ),
                                      if (messageType != 'text' &&
                                          messageText.isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 6.0),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(messageText,
                                              style: TextStyle(
                                                  color: isMe
                                                      ? Colors.white
                                                          .withOpacity(0.8)
                                                      : Colors.black
                                                          .withOpacity(0.8),
                                                  fontSize: 13,
                                                  fontStyle:
                                                      FontStyle.italic)),
                                              if (isEdited) ...[
                                                SizedBox(width: 4),
                                                Text('(modifié)',
                                                    style: TextStyle(
                                                        color: isMe
                                                            ? Colors.white
                                                                .withOpacity(0.6)
                                                            : Colors.black
                                                                .withOpacity(0.6),
                                                        fontSize: 11,
                                                        fontStyle:
                                                            FontStyle.italic)),
                                              ],
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (_isTimestampVisible[messageId] ?? false)
                                  Padding(
                                    padding: EdgeInsets.only(
                                        right: isMe ? 12.0 : 0,
                                        left: isMe ? 0 : 12.0,
                                        bottom: 4.0),
                                    child: Text(
                                      formattedTime,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600]),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
              child: Row(
                children: [
                                     Expanded(
                     child: Container(
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(25.0),
                         boxShadow: [
                           BoxShadow(
                             offset: Offset(0, 1),
                             blurRadius: 3,
                             color: Colors.black.withOpacity(0.1),
                           ),
                         ],
                       ),
                       child: TextField(
                         controller: _controller,
                        enabled: _recordingPath == null,
                         decoration: InputDecoration(
                           hintText: _recordingPath != null ? 'Vocal enregistré - tapez pour l\'annuler' : 'Entrez un message...',
                           border: InputBorder.none,
                           contentPadding: EdgeInsets.symmetric(
                               horizontal: 20, vertical: 14),
                           hintStyle: TextStyle(
                             color: _recordingPath != null ? Colors.orange[600] : Colors.grey[500],
                           ),
                         ),
                         onSubmitted: (_) => _sendMessage(),
                         onTap: () {
                           if (_recordingPath != null) {
                             setState(() {
                               _recordingPath = null;
                             });
                           }
                         },
                       ),
                     ),
                   ),
                  SizedBox(width: 5),
                  IconButton(
                    icon: const Icon(Icons.attach_file,
                        color: Colors.blueAccent),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        builder: (BuildContext context) {
                          return Container(
                            decoration: BoxDecoration(
                                color: Theme.of(context).canvasColor,
                                borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20))),
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading:
                                      const Icon(Icons.image, color: Colors.blue),
                                  title: const Text('Image'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickImage();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.insert_drive_file,
                                      color: Colors.blue),
                                  title: const Text('Document'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _pickDocument();
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera_alt,
                                      color: Colors.blue),
                                  title: const Text('Caméra'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _takePhoto();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                                                                           if (_recordingPath != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _isAudioPlaying && _currentlyPlayingAudioUrl == _recordingPath
                                    ? Icons.pause_circle
                                    : Icons.play_circle,
                                color: Colors.blue,
                                size: 24,
                              ),
                              onPressed: () async {
                                if (_isAudioPlaying && _currentlyPlayingAudioUrl == _recordingPath) {
                                  await _audioPlayer.pausePlayer();
                                  setState(() {
                                    _isAudioPlaying = false;
                                  });
                                } else {
                                  if (_isAudioPlaying) {
                                    await _audioPlayer.stopPlayer();
                                  }
                                  setState(() {
                                    _currentlyPlayingAudioUrl = _recordingPath;
                                    _isAudioPlaying = true;
                                  });
                                  await _audioPlayer.startPlayer(
                                    fromURI: _recordingPath!,
                                    whenFinished: () {
                                      if (mounted) {
                                        setState(() {
                                          _isAudioPlaying = false;
                                          _currentlyPlayingAudioUrl = null;
                                        });
                                      }
                                    },
                                  );
                                }
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red, size: 20),
                              onPressed: _deleteRecording,
                              tooltip: 'Supprimer l\'enregistrement',
                            ),
                          ],
                        ),
                      ),
                       Material(
                         color: Colors.blue,
                         borderRadius: BorderRadius.circular(25),
                         child: InkWell(
                           borderRadius: BorderRadius.circular(25),
                           onTap: _sendMessage,
                           child: Padding(
                             padding: const EdgeInsets.all(12.0),
                             child: Icon(Icons.send_rounded, color: Colors.white, size: 24),
                           ),
                         ),
                       ),
                    ] else
                      IconButton(
                        icon: Icon(
                            _isRecording
                                ? Icons.stop_circle_outlined
                                : Icons.mic_none_outlined,
                            color: _isRecording
                                ? Colors.redAccent
                                : Colors.blueAccent,
                                size: 28),
                        onPressed: _toggleRecording,
                      ),
                                                                            if (_recordingPath == null)
                                                                              Material(
                                                color: Colors.blue,
                                                borderRadius: BorderRadius.circular(25),
                                                child: InkWell(
                                                  borderRadius: BorderRadius.circular(25),
                                                  onTap: _sendMessage,
                                                  child: Padding(
                                                    padding: const EdgeInsets.all(12.0),
                                                    child: Icon(Icons.send_rounded, color: Colors.white, size: 24),
                                                  ),
                                                ),
                                              ),
                ],
              ),
            ),
          ],
        ),
      );

      if (isDesktop) {
        return Scaffold(
          backgroundColor: Colors.blueGrey[50],
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 900),
              child: Card(
                margin:
                    const EdgeInsets.symmetric(vertical: 24.0, horizontal: 24.0),
                elevation: 8.0,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: chatScaffold,
              ),
            ),
          ),
        );
      } else {
        return chatScaffold;
      }
    });
  }

  Widget _buildAudioPlayerWidget(String audioUrl, String fileName, String messageId, bool isMe) {
    bool isCurrentlyPlayingThisSpecificAudio = _currentlyPlayingAudioUrl == audioUrl;
    bool isPlaying = isCurrentlyPlayingThisSpecificAudio && _isAudioPlaying;

    Color iconColor = isMe ? Colors.white : Colors.blue;
    Color textColor = isMe ? Colors.white : Colors.black87;
    Color progressColor = isMe ? Colors.white70 : Colors.blue.withOpacity(0.7);
    Color thumbColor = isMe ? Colors.white : Colors.blue;

    Duration? currentPosition = isCurrentlyPlayingThisSpecificAudio ? _audioPosition : Duration.zero;
    Duration? totalDuration = isCurrentlyPlayingThisSpecificAudio ? _audioDuration : null;

    String formatDuration(Duration? d) {
      if (d == null) return "--:--";
      String twoDigits(int n) => n.toString().padLeft(2, "0");
      String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
      String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
      if (d.inHours > 0) {
        return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
      }
      return "$twoDigitMinutes:$twoDigitSeconds";
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_circle : Icons.play_circle, 
              color: iconColor, 
              size: 32
            ),
            onPressed: () async {
              await _playAudio(audioUrl, messageId);
            },
            tooltip: isPlaying ? 'Pause' : 'Écouter',
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.0,
                    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 14.0),
                    thumbColor: (isCurrentlyPlayingThisSpecificAudio && totalDuration != null && totalDuration.inMilliseconds > 0) ? thumbColor : Colors.transparent,
                    overlayColor: (isCurrentlyPlayingThisSpecificAudio && totalDuration != null && totalDuration.inMilliseconds > 0) ? thumbColor.withOpacity(0.3) : Colors.transparent,
                    activeTrackColor: (isCurrentlyPlayingThisSpecificAudio && totalDuration != null && totalDuration.inMilliseconds > 0) ? progressColor : progressColor.withOpacity(0.3),
                    inactiveTrackColor: (isCurrentlyPlayingThisSpecificAudio && totalDuration != null && totalDuration.inMilliseconds > 0) ? progressColor.withOpacity(0.3) : progressColor.withOpacity(0.1),
                  ),
                  child: Slider(
                    min: 0.0,
                    max: (totalDuration != null && totalDuration.inMilliseconds > 0) ? totalDuration.inMilliseconds.toDouble() : 1.0,
                    value: (currentPosition?.inMilliseconds.toDouble() ?? 0.0)
                        .clamp(0.0, (totalDuration?.inMilliseconds.toDouble() ?? 1.0)),
                    onChanged: null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0).copyWith(top:0.0, bottom: 2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatDuration(currentPosition), style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
                      Text(formatDuration(totalDuration), style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.7))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isMe)
            IconButton(
              icon: Icon(
                Icons.delete_forever_outlined, 
                color: Colors.red.shade600, 
                size: 24
              ),
              onPressed: () => _deleteAudioMessage(messageId),
              tooltip: 'Supprimer le message vocal',
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentWidget(String fileUrl, String fileName, bool isMe) {
    Color iconColor = isMe ? Colors.white : Colors.blue;
    Color textColor = isMe ? Colors.white : Colors.black87;
    return InkWell(
      onTap: () async {
        if (await canLaunchUrl(Uri.parse(fileUrl))) {
          await launchUrl(Uri.parse(fileUrl), mode: LaunchMode.externalApplication);
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible d\'ouvrir le fichier.')));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 15.0, horizontal: 4.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_outlined, color: iconColor, size: 28),
            const SizedBox(width: 8),
            Expanded(child: Text(fileName, style: TextStyle(color: textColor), overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }

  // Vérifier si un message peut être édité ou supprimé (dans les 15 minutes)
  bool _canEditOrDeleteMessage(Timestamp? timestamp) {
    if (timestamp == null) return false;
    
    final now = DateTime.now();
    final messageTime = timestamp.toDate();
    final difference = now.difference(messageTime);
    
    // 15 minutes = 900 secondes
    return difference.inSeconds <= 900;
  }

  // Afficher le menu d'actions pour un message (clic long)
  void _showMessageActions(String messageId, String messageText, String messageType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (messageType == 'text') ...[
              ListTile(
                leading: Icon(Icons.edit, color: Colors.blue),
                title: Text('Modifier le message', style: GoogleFonts.roboto()),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(messageId, messageText);
                },
              ),
              Divider(height: 1),
            ],
            ListTile(
              leading: Icon(Icons.delete_outline, color: Colors.orange),
              title: Text('Supprimer pour moi', style: GoogleFonts.roboto()),
              onTap: () {
                Navigator.pop(context);
                _deleteMessageForMe(messageId);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: Text('Supprimer pour tout le monde', style: GoogleFonts.roboto()),
              onTap: () {
                Navigator.pop(context);
                _deleteMessageForEveryone(messageId, messageType);
              },
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Éditer un message
  void _editMessage(String messageId, String currentText) {
    final TextEditingController editController = TextEditingController(text: currentText);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Modifier le message', style: GoogleFonts.roboto(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: editController,
          decoration: InputDecoration(
            hintText: 'Modifiez votre message...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: GoogleFonts.roboto()),
          ),
          ElevatedButton(
            onPressed: () {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != currentText) {
                _updateMessage(messageId, newText);
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('Modifier', style: GoogleFonts.roboto()),
          ),
        ],
      ),
    );
  }

  // Mettre à jour un message dans Firestore
  void _updateMessage(String messageId, String newText) async {
    try {
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(messageId)
          .update({
        'message': newText,
        'isEdited': true,
        'editedAt': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message modifié avec succès', 
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            )
          ),
          backgroundColor: Colors.blue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la modification: $e', 
            style: GoogleFonts.roboto(color: Colors.white)
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  // Supprimer le message pour soi seulement
  void _deleteMessageForMe(String messageId) async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      await FirebaseFirestore.instance
          .collection('messages')
          .doc(messageId)
          .update({
        'deletedFor': FieldValue.arrayUnion([currentUserId]),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message supprimé pour vous', 
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            )
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: $e', 
            style: GoogleFonts.roboto(color: Colors.white)
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Supprimer le message pour tout le monde
  void _deleteMessageForEveryone(String messageId, String messageType) async {
    try {
      // Supprimer le fichier du storage si c'est un fichier
      if (messageType == 'image' || messageType == 'audio' || messageType == 'document') {
        final messageDoc = await FirebaseFirestore.instance
            .collection('messages')
            .doc(messageId)
            .get();
        
        if (messageDoc.exists) {
          final data = messageDoc.data() as Map<String, dynamic>;
          final fileUrl = data['fileUrl'] as String?;
          
          if (fileUrl != null) {
            try {
              final ref = FirebaseStorage.instance.refFromURL(fileUrl);
              await ref.delete();
            } catch (e) {
              print('Erreur lors de la suppression du fichier: $e');
            }
          }
        }
      }

      // Supprimer le message de Firestore
      await FirebaseFirestore.instance
          .collection('messages')
          .doc(messageId)
          .delete();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Message supprimé pour tout le monde', 
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            )
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression: $e', 
            style: GoogleFonts.roboto(color: Colors.white)
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAppointmentInfoCard(String markdownMessage, bool isMe, String? address, bool isCurrentLocation, String? messageTypeSpecial) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? Colors.blue.shade200 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec icône
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.calendar_today,
                  color: Colors.blue.shade700,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Informations du rendez-vous',
                  style: GoogleFonts.lato(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Contenu du message markdown parsé avec double-clic pour l'itinéraire
          GestureDetector(
            onDoubleTap: () {
              if (address != null && address.isNotEmpty) {
                _openGoogleMaps(address);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.shade200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMarkdownContent(markdownMessage),
                  if (address != null && address.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          size: 16,
                          color: Colors.blue.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Double-cliquez pour voir l\'itinéraire',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          // Bouton d'itinéraire - toujours affiché pour les messages de rendez-vous
          if (messageTypeSpecial == 'appointment_info' && address != null && address.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade700],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () => _openGoogleMaps(address ?? 'Adresse non disponible'),
                icon: Icon(Icons.directions, color: Colors.white, size: 20),
                label: Text(
                  'Voir l\'itinéraire sur Google Maps',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarkdownContent(String markdownText) {
    List<String> lines = markdownText.split('\n');
    List<Widget> widgets = [];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i];
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Titre principal (avec emoji)
      if (line.startsWith('📅')) {
        widgets.add(
          Text(
            line,
            style: GoogleFonts.lato(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.blue.shade800,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 12));
      } 
      // Labels en gras (Statut:, Date et heure:, etc.)
      else if (line.contains(':') && !line.contains('✅') && !line.contains('⏰') && !line.contains('🗺️')) {
        List<String> parts = line.split(':');
        if (parts.length >= 2) {
          String label = parts[0].trim();
          String value = parts.sublist(1).join(':').trim();
          
          widgets.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label:',
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          );
          widgets.add(const SizedBox(height: 8));
        }
      }
      // Statut avec emoji
      else if (line.contains('✅') || line.contains('⏰')) {
        widgets.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: line.contains('✅') ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: line.contains('✅') ? Colors.green.shade200 : Colors.orange.shade200,
              ),
            ),
            child: Text(
              line,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: line.contains('✅') ? Colors.green.shade800 : Colors.orange.shade800,
              ),
            ),
          ),
        );
        widgets.add(const SizedBox(height: 8));
      }
      // Itinéraire disponible
      else if (line.contains('🗺️')) {
        widgets.add(
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.blue.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.directions, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                Text(
                  line,
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
          ),
        );
        widgets.add(const SizedBox(height: 8));
      }
      // Séparateur
      else if (line.startsWith('---')) {
        widgets.add(
          Divider(
            color: Colors.grey.shade300,
            thickness: 1,
          ),
        );
        widgets.add(const SizedBox(height: 8));
      }
      // Texte en italique (message du médecin)
      else if (line.startsWith('Message envoyé')) {
        widgets.add(
          Text(
            line,
            style: GoogleFonts.roboto(
              fontStyle: FontStyle.italic,
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 4));
      }
      // Texte normal (adresse, message du médecin)
      else if (line.trim().isNotEmpty) {
        widgets.add(
          Text(
            line,
            style: GoogleFonts.roboto(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
        );
        widgets.add(const SizedBox(height: 4));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Future<void> _openGoogleMaps(String address) async {
    try {
      // Nettoyer l'adresse (enlever les emojis et caractères spéciaux)
      String cleanAddress = address
          .replaceAll('📍', '')
          .replaceAll('Position actuelle:', '')
          .trim();
      
      // Encoder l'adresse pour l'URL
      String encodedAddress = Uri.encodeComponent(cleanAddress);
      
      // URL pour Google Maps
      String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$encodedAddress';
      
      // Vérifier si l'URL peut être lancée
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible d\'ouvrir Google Maps'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ouverture de Google Maps: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
