import 'package:flutter/material.dart';

import '../models/analysis_history.dart';
import '../screens/analysis_result_screen.dart';
import '../services/history_service.dart';

class HistoryCard extends StatelessWidget {
	const HistoryCard({
		super.key,
		required this.history,
		required this.onDeleted,
	});

	final AnalysisHistory history;
	final VoidCallback onDeleted;

	String _formatDateTime(DateTime dateTime) {
		final period = dateTime.hour < 12 ? '오전' : '오후';
		var hour = dateTime.hour % 12;
		if (hour == 0) {
			hour = 12;
		}
		final minute = dateTime.minute.toString().padLeft(2, '0');
		return '${dateTime.year}년 ${dateTime.month}월 ${dateTime.day}일 $period $hour:$minute';
	}

	List<Map<String, dynamic>> _toIngredientArguments(List<HistoryIngredient> ingredients) {
		return ingredients
				.map(
					(item) => {
						'name': item.name,
						'caution': item.caution,
						'description': item.description,
						'engName': item.engName,
						'eng_name': item.engName,
						'classification': item.classification,
										'uses': item.uses,
					},
				)
				.toList(growable: false);
	}

	Future<void> _confirmDelete(BuildContext context) async {
		final confirmed = await showDialog<bool>(
			context: context,
			builder: (dialogContext) {
				return AlertDialog(
					title: const Text('기록 삭제'),
					content: const Text('이 기록을 삭제하시겠습니까?'),
					actions: [
						TextButton(
							onPressed: () => Navigator.pop(dialogContext, false),
							child: const Text('취소'),
						),
						FilledButton(
							onPressed: () => Navigator.pop(dialogContext, true),
							child: const Text('확인'),
						),
					],
				);
			},
		);

		if (confirmed != true) {
			return;
		}

		await HistoryService.deleteHistory(history.id);
		onDeleted();
	}

	@override
	Widget build(BuildContext context) {
		final isSafe = history.avoidCount == 0;

		return Container(
			margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
			decoration: BoxDecoration(
				color: Colors.white,
				borderRadius: BorderRadius.circular(18),
				border: Border.all(color: const Color(0xFFE2E8F0)),
				boxShadow: const [
					BoxShadow(
						color: Color(0x12000000),
						blurRadius: 10,
						offset: Offset(0, 3),
					),
				],
			),
			child: InkWell(
				borderRadius: BorderRadius.circular(16),
				onTap: () async {
					await Navigator.push(
						context,
						MaterialPageRoute(
							builder: (_) => const AnalysisResultScreen(),
							settings: RouteSettings(
								arguments: {
									'product_name': history.productName,
									'ingredients': _toIngredientArguments(history.ingredients),
									'user_avoid_ingredients': history.userAvoidIngredients,
									'is_history_view': true,
									'history_id': history.id,
								},
							),
						),
					);
					onDeleted();
				},
				onLongPress: () => _confirmDelete(context),
				child: Padding(
					padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
					child: Column(
						crossAxisAlignment: CrossAxisAlignment.start,
						children: [
							Row(
								children: [
									Expanded(
										child: Text(
											history.productName,
											style: const TextStyle(
												fontSize: 32 / 2,
												fontWeight: FontWeight.w800,
												color: Color(0xFF0F172A),
											),
										),
									),
									IconButton(
										tooltip: '삭제',
										onPressed: () => _confirmDelete(context),
										icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8)),
									),
									Container(
										padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
										decoration: BoxDecoration(
											color: isSafe ? const Color(0xFFE9F8EE) : const Color(0xFFFEE2E2),
											borderRadius: BorderRadius.circular(12),
											border: Border.all(
												color: isSafe ? const Color(0xFFB8ECCA) : const Color(0xFFFCA5A5),
											),
										),
										child: Text(
											isSafe ? '● 안전' : '● 주의',
											style: TextStyle(
												fontSize: 13,
												fontWeight: FontWeight.w700,
												color: isSafe ? const Color(0xFF159947) : const Color(0xFFB91C1C),
											),
										),
									),
								],
							),
							const SizedBox(height: 6),
							Text(
								_formatDateTime(history.analyzedDate),
								style: const TextStyle(
									fontSize: 13,
									color: Color(0xFF64748B),
									fontWeight: FontWeight.w500,
								),
							),
							const SizedBox(height: 8),
							Text(
								'중 ${history.ingredientCount}개 성분 검출',
								style: const TextStyle(
									fontSize: 14,
									color: Color(0xFF1E293B),
									fontWeight: FontWeight.w600,
								),
							),
						],
					),
				),
			),
		);
	}
}
